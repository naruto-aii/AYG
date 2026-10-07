import 'dart:io';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/sync_failure.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/alcohol_repository_base.dart';
import 'package:ayg/repositories/contracts/exercise_repository_base.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/repositories/contracts/weight_repository_base.dart';
import 'package:ayg/repositories/data_sync_repository.dart';
import 'package:ayg/repositories/local_session_store.dart';
import 'package:ayg/repositories/plus_funnel_repository.dart';
import 'package:ayg/repositories/subscription_repository.dart';
import 'package:ayg/repositories/supabase/exercise_entry_row_mapper.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/screens/subscription/plus_gate.dart';
import 'package:ayg/services/local_user_data_clearer_base.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'empty remote pull keeps local food, exercise, weight, and alcohol',
    () async {
      final food = _food('food-local');
      final exercise = _exercise('exercise-local');
      final alcohol = _alcohol('alcohol-local');
      final weight = _weight('weight-local');

      final keptFood = await _pullEmpty([food], (entry) => entry.id);
      final keptExercise = await _pullEmpty([exercise], (entry) => entry.id);
      final keptAlcohol = await _pullEmpty([alcohol], (entry) => entry.id);
      final keptWeight = await _pullEmpty([weight], (entry) => entry.id);

      expect(keptFood.map((entry) => entry.id), ['food-local']);
      expect(keptExercise.map((entry) => entry.id), ['exercise-local']);
      expect(keptAlcohol.map((entry) => entry.id), ['alcohol-local']);
      expect(keptWeight.map((entry) => entry.id), ['weight-local']);

      final merged = mergeEntriesById(
        local: [food, _food('food-both')],
        remote: [_food('food-remote'), _food('food-both')],
        idOf: (FoodEntry entry) => entry.id,
      );
      expect(merged.map((entry) => entry.id), [
        'food-remote',
        'food-both',
        'food-local',
      ]);
      expect(
        merged.firstWhere((entry) => entry.id == 'food-both').name,
        'food-both',
      );

      final localEdit = _food('food-both', name: '手元の編集');
      final remoteCopy = _food('food-both', name: '本番');
      final preferred = mergeEntriesById(
        local: [localEdit, _food('food-local')],
        remote: [remoteCopy, _food('food-remote')],
        idOf: (FoodEntry entry) => entry.id,
        preferLocalIds: {'food-both'},
      );
      expect(
        preferred.firstWhere((entry) => entry.id == 'food-both').name,
        '手元の編集',
      );
      expect(preferred.map((entry) => entry.id), [
        'food-both',
        'food-remote',
        'food-local',
      ]);

      final deleted = mergeEntriesById(
        local: [_food('food-local')],
        remote: [_food('food-gone'), _food('food-remote')],
        idOf: (FoodEntry entry) => entry.id,
        pendingDeleteIds: {'food-gone'},
      );
      expect(deleted.map((entry) => entry.id), ['food-remote', 'food-local']);
    },
  );

  test('one failed table does not stop the later tables', () async {
    final sent = <String>[];
    await expectLater(
      runPushSteps([
        (table: 'food_entries', action: () async => sent.add('food')),
        (
          table: 'exercise_entries',
          action: () async => throw StateError('exercise down'),
        ),
        (table: 'alcohol_entries', action: () async => sent.add('alcohol')),
        (table: 'weight_entries', action: () async => sent.add('weight')),
      ]),
      throwsA(
        isA<PartialPushException>().having(
          (error) => error.failures.map((failure) => failure.table).toList(),
          'tables',
          ['exercise_entries'],
        ),
      ),
    );
    expect(sent, ['food', 'alcohol', 'weight']);
  });

  test('PGRST204 drops the named column and retries', () async {
    final attempts = <List<String>>[];
    await upsertDroppingUnknownColumns(
      table: 'food_entries',
      rows: [
        {
          'user_id': 'user-1',
          'entry_id': 'food-1',
          'name': 'ごはん',
          'quantity': 1,
          'logged_at': '2026-10-07T12:00:00.000',
          'record_origin': 'widget',
          'memo': '夜',
        },
      ],
      requiredColumns: foodEntryRequiredColumns,
      upsert: (rows) async {
        attempts.add(rows.single.keys.toList());
        if (attempts.length == 1) {
          throw const PostgrestException(
            message:
                "Could not find the 'record_origin' column of 'food_entries' in the schema cache",
            code: 'PGRST204',
          );
        }
        if (attempts.length == 2) {
          throw const PostgrestException(
            message: 'column "memo" of relation "food_entries" does not exist',
            code: '42703',
          );
        }
      },
    );

    expect(attempts, hasLength(3));
    expect(attempts[1], isNot(contains('record_origin')));
    expect(attempts[1], contains('memo'));
    expect(attempts[2], isNot(contains('record_origin')));
    expect(attempts[2], isNot(contains('memo')));
    expect(attempts[2], contains('entry_id'));
  });

  test('a required column is not removed', () async {
    await expectLater(
      upsertDroppingUnknownColumns(
        table: 'food_entries',
        rows: [
          {'entry_id': 'food-1', 'name': 'ごはん'},
        ],
        requiredColumns: foodEntryRequiredColumns,
        upsert: (rows) async {
          throw const PostgrestException(
            message:
                "Could not find the 'entry_id' column of 'food_entries' in the schema cache",
            code: 'PGRST204',
          );
        },
      ),
      throwsA(isA<PostgrestException>()),
    );
  });

  test('row mappers send record_origin', () {
    final food = FoodMasterRowMapper.foodEntryToRow(
      _food('food-1', origin: 'siri'),
      userId: 'user-1',
    );
    final exercise = ExerciseEntryRowMapper.toRow(
      _exercise('exercise-1', origin: 'widget'),
      userId: 'user-1',
    );
    expect(food['record_origin'], 'siri');
    expect(exercise['record_origin'], 'widget');
  });

  test(
    'offline records survive restart and are sent on the next launch',
    () async {
      SharedPreferences.setMockInitialValues({
        'last_authenticated_user_id': 'user-1',
      });
      final harness = await IsarTestHarness.create();
      addTearDown(harness.dispose);
      await harness.foodRepository.save(_food('food-1', origin: 'app'));
      await harness.exerciseRepository.save(
        _exercise('exercise-1', origin: 'widget'),
      );
      await harness.alcoholRepository.save(_alcohol('alcohol-1'));
      await harness.weightRepository.save(_weight('weight-1'));

      final clearer = _SpyClearer();
      final sync =
          _RecordingSync(
              foods: harness.foodRepository,
              exercises: harness.exerciseRepository,
              alcohol: harness.alcoholRepository,
              weights: harness.weightRepository,
            )
            ..offline = true
            ..failPull = true;
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      final first = AppController(
        authenticationRepository: auth,
        dataSyncRepository: sync,
        localSessionStore: LocalSessionStore(),
        localUserDataClearer: clearer,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        alcoholRepository: harness.alcoholRepository,
        weightRepository: harness.weightRepository,
      );

      await first.handleAuthenticatedSession();

      expect(sync.order, ['push', 'pull']);
      expect(clearer.clears, 0);
      expect(first.lastSyncFailed, isTrue);
      expect(
        (await harness.foodRepository.loadAll()).map((entry) => entry.id),
        ['food-1'],
      );
      expect(
        (await harness.exerciseRepository.loadAll()).map((entry) => entry.id),
        ['exercise-1'],
      );
      expect(
        (await harness.alcoholRepository.loadAll()).map((entry) => entry.id),
        ['alcohol-1'],
      );
      expect(
        (await harness.weightRepository.loadAll()).map((entry) => entry.id),
        ['weight-1'],
      );

      sync.offline = false;
      sync.failPull = false;
      sync.order.clear();
      final second = AppController(
        authenticationRepository: auth,
        dataSyncRepository: sync,
        localSessionStore: LocalSessionStore(),
        localUserDataClearer: clearer,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        alcoholRepository: harness.alcoholRepository,
        weightRepository: harness.weightRepository,
      );
      await second.handleAuthenticatedSession();

      expect(sync.order.first, 'push');
      expect(sync.pushed['food'], ['food-1']);
      expect(sync.pushed['exercise'], ['exercise-1']);
      expect(sync.pushed['alcohol'], ['alcohol-1']);
      expect(sync.pushed['weight'], ['weight-1']);
      expect(
        (await harness.foodRepository.loadAll()).single.recordOrigin,
        'app',
      );
      expect(clearer.clears, 0);
      expect(second.hasUnsentRecords, isFalse);

      await auth.dispose();
    },
  );

  test('plus funnel insert row names the event and feature', () {
    expect(
      plusFunnelInsertRow(
        event: PlusFunnelEvent.purchaseSuccess,
        feature: PlusFunnelFeature.coach,
        productId: 'calonavi_plus_yearly',
      ),
      {
        'event': 'purchase_success',
        'feature': 'coach',
        'product_id': 'yearly',
        'advertising_use': false,
      },
    );
    expect(
      plusFunnelInsertRow(
        event: PlusFunnelEvent.planSelect,
        productId: SubscriptionCatalog.monthlyProductId,
      )['product_id'],
      'monthly',
    );
    expect(
      plusFunnelInsertRow(
        event: PlusFunnelEvent.purchaseTap,
        productId: SubscriptionCatalog.halfYearProductId,
      )['product_id'],
      'half-year',
    );
    expect(
      plusFunnelInsertRow(
        event: PlusFunnelEvent.restoreTap,
        productId: SubscriptionCatalog.yearlyProductId,
      )['product_id'],
      'yearly',
    );
    expect(
      plusFunnelInsertRow(
        event: PlusFunnelEvent.purchaseCancel,
        productId: 'yearly',
      )['product_id'],
      'yearly',
    );
    expect(
      plusFunnelInsertRow(
        event: PlusFunnelEvent.purchaseFailed,
        productId: 'monthly',
      )['product_id'],
      'monthly',
    );
    final planSelect = _sql('20261007122159_plus_funnel_plan_select.sql');
    expect(planSelect, contains("'plan_select'"));
    expect(planSelect, isNot(contains('delete_own_account')));
  });

  testWidgets('the paid gate records shown and tap', (tester) async {
    final funnel = _MemoryFunnel();
    final controller = AppController(
      authenticationRepository: MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      ),
      subscriptionRepository: _ScriptedPlus(),
      plusFunnelRepository: funnel,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => ensureCalonaviPlus(
                context,
                controller,
                message: 'パーソナルコーチはカロナビ+です。',
                feature: PlusFunnelFeature.coach,
              ),
              child: const Text('coach'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('coach'));
    await tester.pumpAndSettle();
    expect(funnel.events.single.event, PlusFunnelEvent.gateShown);

    await tester.tap(find.text('カロナビ+を見る'));
    await tester.pumpAndSettle();
    expect(funnel.events.map((event) => event.event), [
      PlusFunnelEvent.gateShown,
      PlusFunnelEvent.gateTap,
      PlusFunnelEvent.paywallOpen,
    ]);
    expect(
      funnel.events.every((event) => event.feature == PlusFunnelFeature.coach),
      isTrue,
    );
  });

  testWidgets('paywall sends open, purchase, and restore', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final funnel = _MemoryFunnel();
    final plus = _ScriptedPlus();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () => showCalonaviPlus(
                context,
                repository: plus,
                feature: PlusFunnelFeature.memo,
                funnel: funnel,
              ),
              child: const Text('open'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(funnel.events.single.event, PlusFunnelEvent.paywallOpen);
    expect(funnel.events.single.feature, PlusFunnelFeature.memo);

    await tester.ensureVisible(find.byKey(const Key('plus-plan-monthly')));
    await tester.tap(find.byKey(const Key('plus-plan-monthly')));
    await tester.pumpAndSettle();
    expect(
      funnel.events
          .firstWhere((event) => event.event == PlusFunnelEvent.planSelect)
          .productId,
      'monthly',
    );

    await tester.ensureVisible(find.byKey(const Key('plus-plan-halfYear')));
    await tester.tap(find.byKey(const Key('plus-plan-halfYear')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('plus-plan-yearly')));
    await tester.tap(find.byKey(const Key('plus-plan-yearly')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('plus-purchase')));
    await tester.pumpAndSettle();
    expect(
      funnel.events.map((event) => event.event),
      containsAll([
        PlusFunnelEvent.purchaseTap,
        PlusFunnelEvent.purchaseSuccess,
      ]),
    );
    expect(
      funnel.events
          .firstWhere((event) => event.event == PlusFunnelEvent.purchaseTap)
          .productId,
      'yearly',
    );

    await tester.pump(const Duration(seconds: 5));
    plus.active = false;
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('購入を復元'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('購入を復元'));
    await tester.pumpAndSettle();
    expect(
      funnel.events.map((event) => event.event),
      contains(PlusFunnelEvent.restoreTap),
    );
    expect(
      funnel.events
          .lastWhere((event) => event.event == PlusFunnelEvent.restoreTap)
          .productId,
      'yearly',
    );

    await tester.tap(find.byKey(const Key('calonavi-plus-close')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    plus.failPurchase = true;
    funnel.events.clear();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plus-purchase')));
    await tester.pumpAndSettle();
    expect(
      funnel.events.map((event) => event.event),
      contains(PlusFunnelEvent.purchaseFailed),
    );
    expect(
      funnel.events
          .firstWhere((event) => event.event == PlusFunnelEvent.purchaseFailed)
          .productId,
      'yearly',
    );
    expect(find.text('購入できませんでした'), findsOneWidget);
  });

  test('migration files keep the record and billing changes', () {
    final rls = _sql('20261007160000_food_search_spellings_rls.sql');
    expect(rls, contains('enable row level security'));
    expect(rls, contains('for select'));
    expect(rls, contains('to authenticated'));
    expect(
      rls,
      contains('revoke all on table public.food_search_spellings from anon'),
    );
    expect(
      rls,
      contains(
        'revoke all on table public.food_search_spellings from authenticated',
      ),
    );

    final miso = _sql(
      '20261007161000_remove_miso_soup_aliases_from_instant_miso.sql',
    );
    expect(miso, contains("source = 'spoken_manual_v1'"));
    expect(miso, contains("food_code = '17049'"));
    expect(miso, contains("food_code = '17050'"));

    final blocked = _sql('20261007162000_blocked_food_creators_update_own.sql');
    expect(
      blocked,
      contains(
        'create policy blocked_food_creators_update_own on public.blocked_food_creators for update to authenticated using ((select auth.uid()) = blocker_user_id) with check ((select auth.uid()) = blocker_user_id);',
      ),
    );

    final funnel = _sql('20261007090000_plus_funnel_events.sql');
    expect(
      funnel,
      contains('create table if not exists public.plus_funnel_events'),
    );
    expect(funnel, contains('paywall_open'));
    expect(funnel, contains('meal_template_limit'));
    expect(funnel, contains('advertising_use boolean not null default false'));
    expect(funnel, contains('plus_funnel_events_user_occurred_idx'));
    expect(
      funnel,
      contains('delete from public.plus_funnel_events where user_id = \$1'),
    );

    final origin = _sql('20261007074319_record_origin.sql');
    expect(origin, contains('alter table public.food_entries'));
    expect(origin, contains('alter table public.exercise_entries'));
    expect(origin, contains('add column if not exists record_origin text'));
  });
}

Future<List<T>> _pullEmpty<T>(
  List<T> local,
  String Function(T entry) idOf,
) async {
  final stored = [...local];
  await mergeRepositoryEntries<T>(
    loadLocal: () async => stored,
    remote: <T>[],
    idOf: idOf,
    clearAll: () async => stored.clear(),
    saveAll: (entries) async => stored.addAll(entries),
  );
  return stored;
}

FoodEntry _food(String id, {String? origin, String? name}) {
  return FoodEntry(
    id: id,
    name: name ?? id,
    quantity: 1,
    recordOrigin: origin,
    loggedAt: DateTime(2026, 10, 7, 12),
  );
}

ExerciseEntry _exercise(String id, {String? origin}) {
  return ExerciseEntry(
    id: id,
    name: id,
    durationMin: 20,
    burnedKcal: 80,
    recordOrigin: origin,
    loggedAt: DateTime(2026, 10, 7, 12),
  );
}

AlcoholEntry _alcohol(String id) {
  return AlcoholEntry(
    id: id,
    beverageName: id,
    amount: 350,
    unit: 'ml',
    alcoholPercentage: 5,
    totalCalories: 140,
    pureAlcoholGrams: 14,
    alcoholCalories: 98,
    consumedAt: DateTime(2026, 10, 7, 20),
  );
}

WeightEntry _weight(String id) {
  return WeightEntry(
    id: id,
    weightKg: 60,
    recordedAt: DateTime(2026, 10, 7, 7),
    source: WeightSource.manual,
  );
}

class _SpyClearer implements LocalUserDataClearerBase {
  int clears = 0;

  @override
  Future<void> clearAll() async {
    clears++;
  }
}

class _RecordingSync extends MockDataSyncRepository {
  _RecordingSync({
    required this.foods,
    required this.exercises,
    required this.alcohol,
    required this.weights,
  });

  final FoodRepositoryBase foods;
  final ExerciseRepositoryBase exercises;
  final AlcoholRepositoryBase alcohol;
  final WeightRepositoryBase weights;
  bool offline = false;
  final order = <String>[];
  final pushed = <String, List<String>>{};

  @override
  Future<void> pushLocalToRemote(String userId) async {
    order.add('push');
    pushLocalToRemoteCalled = true;
    lastUserId = userId;
    if (offline) {
      throw PartialPushException([
        (table: 'food_entries', error: StateError('offline')),
      ]);
    }
    pushed['food'] = [for (final entry in await foods.loadAll()) entry.id];
    pushed['exercise'] = [
      for (final entry in await exercises.loadAll()) entry.id,
    ];
    pushed['alcohol'] = [for (final entry in await alcohol.loadAll()) entry.id];
    pushed['weight'] = [for (final entry in await weights.loadAll()) entry.id];
  }

  @override
  Future<void> pullRemoteToLocal(
    String userId, {
    Set<String> skipTables = const {},
  }) async {
    order.add('pull');
    pullRemoteToLocalCalled = true;
    lastUserId = userId;
    if (failPull) {
      throw SyncStepException(
        SyncFailure.from(
          step: SyncStep.fetchFoodEntries,
          error: StateError('offline'),
          repository: 'RecordingSync',
          tableName: 'food_entries',
          operation: 'select',
        ),
      );
    }
    await mergeRepositoryEntries(
      loadLocal: foods.loadAll,
      remote: const <FoodEntry>[],
      idOf: (entry) => entry.id,
      clearAll: foods.clearAll,
      saveAll: foods.saveAll,
    );
    await mergeRepositoryEntries(
      loadLocal: exercises.loadAll,
      remote: const <ExerciseEntry>[],
      idOf: (entry) => entry.id,
      clearAll: exercises.clearAll,
      saveAll: exercises.saveAll,
    );
    await mergeRepositoryEntries(
      loadLocal: alcohol.loadAll,
      remote: const <AlcoholEntry>[],
      idOf: (entry) => entry.id,
      clearAll: alcohol.clearAll,
      saveAll: alcohol.saveAll,
    );
    await mergeRepositoryEntries(
      loadLocal: weights.loadAll,
      remote: const <WeightEntry>[],
      idOf: (entry) => entry.id,
      clearAll: weights.clearAll,
      saveAll: (entries) async {
        for (final entry in entries) {
          await weights.save(entry);
        }
      },
    );
  }
}

class _FunnelEvent {
  _FunnelEvent(this.event, this.feature, this.productId);

  final PlusFunnelEvent event;
  final PlusFunnelFeature? feature;
  final String? productId;
}

class _MemoryFunnel implements PlusFunnelRepository {
  final events = <_FunnelEvent>[];

  @override
  Future<void> record({
    required PlusFunnelEvent event,
    PlusFunnelFeature? feature,
    String? productId,
  }) async {
    events.add(_FunnelEvent(event, feature, productId));
  }

  @override
  Future<void> flushPending() async {}
}

class _ScriptedPlus extends SubscriptionRepository {
  bool active = false;
  bool failPurchase = false;

  @override
  bool get isPlusActive => active;

  @override
  Stream<bool> get plusChanges => const Stream.empty();

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return SubscriptionOfferings.failed;
  }

  @override
  Future<void> restore() async {}

  @override
  Future<void> refreshEntitlement() async {}

  @override
  Future<void> purchaseMonthly() => purchasePlan(PlusPlan.monthly);

  @override
  Future<void> purchaseYearly() => purchasePlan(PlusPlan.yearly);

  @override
  Future<void> purchasePlan(PlusPlan plan) async {
    if (failPurchase) {
      throw StateError('store failed');
    }
    active = true;
  }
}

String _sql(String name) {
  return File('supabase/migrations/$name').readAsStringSync();
}
