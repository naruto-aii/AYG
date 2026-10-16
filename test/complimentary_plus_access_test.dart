import 'dart:io';

import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/complimentary_plus_repository.dart';
import 'package:ayg/repositories/subscription_exceptions.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/services/complimentary_plus.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  test('access is the store flag or the complimentary flag', () {
    expect(calonaviPlusAccess(storePlus: false, complimentary: false), isFalse);
    expect(calonaviPlusAccess(storePlus: false, complimentary: true), isTrue);
    expect(calonaviPlusAccess(storePlus: true, complimentary: false), isTrue);
    expect(calonaviPlusAccess(storePlus: true, complimentary: true), isTrue);
    expect(complimentaryPlusFromRpc(true), isTrue);
    expect(complimentaryPlusFromRpc(false), isFalse);
    expect(complimentaryPlusFromRpc(null), isFalse);
    expect(complimentaryPlusFromRpc('true'), isFalse);
  });

  test(
    'a complimentary login can use Plus while the store stays unpaid',
    () async {
      final harness = await IsarTestHarness.create();
      addTearDown(harness.dispose);
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'president-a', email: 'a@example.test'),
      );
      final loader = _Scripted(auth)..byUserId['president-a'] = true;
      final store = _StorePlus(false);
      final controller = _controller(
        harness,
        auth: auth,
        store: store,
        complimentary: loader,
      );
      addTearDown(controller.dispose);

      await controller.refreshComplimentaryPlus();

      expect(controller.hasCalonaviPlusAccess, isTrue);
      expect(controller.subscriptionRepository.isPlusActive, isFalse);
      expect(controller.subscriptionRepository.confirmedEntitlements, isEmpty);
      for (var index = 0; index < 5; index++) {
        await controller.saveMealTemplate(draft: _draft('朝食$index'));
      }
      expect(
        await harness.mealTemplateRepository.getAll('president-a'),
        hasLength(5),
      );
    },
  );

  test('any other login stays on the free limit', () async {
    final harness = await IsarTestHarness.create();
    addTearDown(harness.dispose);
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'ordinary', email: 'o@example.test'),
    );
    final loader = _Scripted(auth)..byUserId['ordinary'] = false;
    final controller = _controller(
      harness,
      auth: auth,
      store: _StorePlus(false),
      complimentary: loader,
    );
    addTearDown(controller.dispose);

    await controller.refreshComplimentaryPlus();

    expect(controller.hasCalonaviPlusAccess, isFalse);
    expect(controller.subscriptionRepository.isPlusActive, isFalse);
    for (var index = 0; index < 4; index++) {
      await controller.saveMealTemplate(draft: _draft('朝食$index'));
    }
    expect(
      controller.saveMealTemplate(draft: _draft('5件目')),
      throwsA(isA<SubscriptionLimitExceededException>()),
    );
  });

  test(
    'a failed lookup keeps the previous answer for the same login',
    () async {
      final harness = await IsarTestHarness.create();
      addTearDown(harness.dispose);
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'president-b', email: 'b@example.test'),
      );
      final loader = _Scripted(auth)..byUserId['president-b'] = true;
      final controller = _controller(
        harness,
        auth: auth,
        store: _StorePlus(false),
        complimentary: loader,
      );
      addTearDown(controller.dispose);

      await controller.refreshComplimentaryPlus();
      loader.fail = true;
      await controller.refreshComplimentaryPlus();
      expect(controller.hasCalonaviPlusAccess, isTrue);
      expect(controller.subscriptionRepository.isPlusActive, isFalse);

      auth.setCurrentUser(
        const AuthUser(id: 'ordinary-2', email: 'o2@example.test'),
      );
      loader.fail = false;
      loader.byUserId['ordinary-2'] = false;
      await controller.refreshComplimentaryPlus();
      expect(controller.hasCalonaviPlusAccess, isFalse);
    },
  );

  test('the migration does not write grants or touch billing and kpi', () {
    const migrationPath =
        'supabase/migrations/20261016093000_complimentary_plus_grants.sql';
    final sql = File(migrationPath).readAsStringSync();
    final executable = sql
        .split('\n')
        .where((line) => !line.trimLeft().startsWith('--'))
        .join('\n')
        .toLowerCase();
    final manual = File(
      'supabase/manual/complimentary_plus_president_grants.sql',
    ).readAsStringSync();

    expect(
      executable,
      contains(
        'create table if not exists public.calonavi_plus_complimentary_grants',
      ),
    );
    expect(executable, contains('auth.uid()'));
    expect(executable, contains('auth.identities'));
    expect(executable, isNot(contains('insert into')));
    expect(executable, isNot(contains('calonavi_plus_entitlements')));
    expect(executable, isNot(contains('kpi_excluded_users')));
    expect(executable, isNot(contains('store_server_notifications')));
    expect(executable, isNot(contains('userlog')));
    expect(executable, isNot(contains('@')));
    expect(manual.toLowerCase(), contains('begin;'));
    expect(manual.toLowerCase(), contains('commit;'));
    expect(manual, contains("reason like 'president\\_%'"));
    expect(
      'u.deleted_at is null'.allMatches(manual).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      'live.deleted_at is null'.allMatches(manual).length,
      greaterThanOrEqualTo(1),
    );
    expect(manual, contains(') = 1'));
    expect(manual, contains('candidate_n <> 3'));
    expect(manual, contains('grant_n <> 3'));
    expect(manual, contains('more than one live user'));
    expect(manual, contains('on conflict (provider, provider_id) do nothing'));
    expect(manual, isNot(contains('@')));
    final bootstrap = File(
      'supabase/tests/complimentary_plus_bootstrap.sql',
    ).readAsStringSync();
    expect(
      bootstrap,
      contains(
        'added_at timestamptz not null default timezone(\'utc\', now())',
      ),
    );
    expect(bootstrap, contains('add column if not exists provider text'));
    expect(bootstrap, contains('kpi_excluded_users_provider_pair'));
    expect(bootstrap, isNot(contains('collect_excluded_user_ids')));
    expect(manual.toLowerCase(), isNot(contains('calonavi_plus_entitlements')));
    expect(manual.toLowerCase(), isNot(contains('store_server_notifications')));

    for (final path in const [
      'lib/screens/subscription/calonavi_plus_flow.dart',
      'lib/repositories/usage_record_repository.dart',
      'supabase/functions/app-store-notifications/handler.ts',
      'supabase/functions/userlog-notify/logic.ts',
      'supabase/functions/userlog-notify/handler.ts',
      'supabase/migrations/20261007112725_kpi_excluded_users.sql',
      'supabase/migrations/20261015032420_userlog_notifications.sql',
      'supabase/migrations/20261015065812_userlog_login_per_install.sql',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('complimentary')),
        reason: path,
      );
    }
    expect(
      File(
        'lib/screens/subscription/calonavi_plus_flow.dart',
      ).readAsStringSync(),
      contains('repository.isPlusActive'),
    );
  });
}

MealTemplateDraft _draft(String name) {
  return MealTemplateDraft(
    name: name,
    items: [
      MealTemplateItemDraft(
        name: 'ご飯',
        baseAmount: 150,
        unitType: FoodUnitType.g,
        kcalPerBase: 234,
        consumedAmount: 150,
        sortOrder: 1,
      ),
    ],
  );
}

AppController _controller(
  IsarTestHarness harness, {
  required MockAuthenticationRepository auth,
  required _StorePlus store,
  required ComplimentaryPlusRepository complimentary,
}) {
  return AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
    authenticationRepository: auth,
    dataSyncRepository: MockDataSyncRepository(),
    subscriptionRepository: store,
    complimentaryPlus: complimentary,
    userRepository: harness.userRepository,
    settingsRepository: harness.settingsRepository,
    foodRepository: harness.foodRepository,
    exerciseRepository: harness.exerciseRepository,
    weightRepository: harness.weightRepository,
    savedFoodRepository: harness.savedFoodRepository,
    mealTemplateRepository: harness.mealTemplateRepository,
  );
}

class _StorePlus extends UnavailableSubscriptionRepository {
  _StorePlus(this.active);

  final bool active;

  @override
  bool get isPlusActive => active;
}

class _Scripted implements ComplimentaryPlusRepository {
  _Scripted(this._auth);

  final MockAuthenticationRepository _auth;
  final Map<String, bool> byUserId = {};
  bool fail = false;

  @override
  Future<bool?> current() async {
    if (fail) {
      return null;
    }
    final id = _auth.currentUser?.id;
    if (id == null) {
      return false;
    }
    return byUserId[id] ?? false;
  }
}
