import 'dart:convert';
import 'dart:typed_data';

import 'package:ayg/app.dart';
import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/app_settings.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/alcohol_repository_base.dart';
import 'package:ayg/repositories/contracts/exercise_repository_base.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/repositories/contracts/settings_repository_base.dart';
import 'package:ayg/repositories/contracts/user_repository_base.dart';
import 'package:ayg/repositories/contracts/weight_repository_base.dart';
import 'package:ayg/repositories/data_sync_repository.dart';
import 'package:ayg/repositories/local_session_store.dart';
import 'package:ayg/screens/legal/terms_agreement_screen.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/ai_food_lookup_client.dart';
import 'package:ayg/services/local_user_data_clearer_base.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/services/siri_voice_gateway.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'helpers/fake_postgrest.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

/// 本番の food_entries は `auth.uid() = user_id` のときだけ書ける。
/// 今のセッションと違う user_id の書き込みは 42501 で拒否する。
class SessionRlsPostgrest extends FakePostgrest {
  SessionRlsPostgrest(this.sessionUserId);

  String sessionUserId;
  final rejectedUserIds = <String>[];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    if (request.method == 'POST' ||
        request.method == 'PATCH' ||
        request.method == 'DELETE') {
      final body = request is Request ? request.body : '';
      if (body.isNotEmpty) {
        final decoded = jsonDecode(body);
        final rows = decoded is List ? decoded : [decoded];
        for (final row in rows) {
          if (row is Map && row.containsKey('user_id')) {
            final owner = '${row['user_id']}';
            if (owner != sessionUserId) {
              rejectedUserIds.add(owner);
              final bytes = utf8.encode(
                jsonEncode({
                  'code': '42501',
                  'message': 'new row violates row-level security policy',
                }),
              );
              return StreamedResponse(
                Stream<List<int>>.value(bytes),
                403,
                headers: {'content-type': 'application/json'},
                request: request,
              );
            }
          }
        }
      }
    }
    return super.send(request);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AiDataConsent.override = MemoryAiDataConsent(granted: true, synced: true);
  });

  test('別アカウントの同意後は、前の未送信を今のユーザーの行にしない', () async {
    final harness = await _Harness.open();
    addTearDown(harness.dispose);

    await harness.controller.handleAuthenticatedSession();
    expect(harness.controller.requiresTermsAgreement, isTrue);
    expect(await harness.controller.declineTermsAgreement(), isTrue);
    expect(harness.foods.entries.map((entry) => entry.id), ['meal-a']);
    expect(await harness.session.loadLastUserId(), 'user-a');
    expect(harness.http.tables['food_entries'] ?? const [], isEmpty);

    harness.agreed = true;
    harness.auth.setCurrentUser(
      const AuthUser(id: 'user-b', email: 'b@example.com'),
    );
    harness.http.sessionUserId = 'user-b';
    await harness.controller.handleAuthenticatedSession();

    expect(harness.controller.requiresSyncRetry, isTrue);
    expect(harness.http.rejectedUserIds, contains('user-a'));
    expect(harness.http.tables['food_entries'] ?? const [], isEmpty);
    expect(_localMeal(harness), {
      'id': 'meal-a',
      'name': '朝食',
      'kcal': 180,
      'loggedAt': DateTime.utc(2026, 10, 8, 8),
    });

    // 再試行画面の「ログアウト」は controller.logout()。
    // 前の人の未送信を、今のユーザーの行にして手元から消してはいけない。
    final left = await harness.controller.logout();
    final serverB = [
      for (final row in harness.http.tables['food_entries'] ?? const [])
        if (row['user_id'] == 'user-b')
          {
            'id': row['entry_id'],
            'name': row['name'],
            'kcal': (row['kcal_per_unit'] as num?)?.toDouble(),
            'loggedAt': row['logged_at'],
          },
    ];
    expect(
      {
        'logoutReturned': left,
        'serverAsUserB': serverB,
        'localIds': [for (final entry in harness.foods.entries) entry.id],
        'lastUserId': await harness.session.loadLastUserId(),
      },
      {
        'logoutReturned': false,
        'serverAsUserB': <Object?>[],
        'localIds': ['meal-a'],
        'lastUserId': 'user-a',
      },
    );
  });

  test('切り替えを止めたあと、前のアカウントで入り直すと同じ件数で送る', () async {
    final harness = await _Harness.open();
    addTearDown(harness.dispose);

    await harness.controller.handleAuthenticatedSession();
    expect(await harness.controller.declineTermsAgreement(), isTrue);

    harness.agreed = true;
    harness.auth.setCurrentUser(
      const AuthUser(id: 'user-b', email: 'b@example.com'),
    );
    harness.http.sessionUserId = 'user-b';
    await harness.controller.handleAuthenticatedSession();
    expect(harness.controller.requiresSyncRetry, isTrue);
    expect(harness.foods.entries, hasLength(1));

    harness.auth.setCurrentUser(
      const AuthUser(id: 'user-a', email: 'a@example.com'),
    );
    harness.http.sessionUserId = 'user-a';
    await harness.controller.handleAuthenticatedSession();

    final rows = harness.http.tables['food_entries'] ?? const [];
    expect(harness.controller.lastSyncFailed, isFalse);
    expect(rows, hasLength(1));
    expect(rows.single['user_id'], 'user-a');
    expect(rows.single['entry_id'], 'meal-a');
    expect(rows.single['name'], '朝食');
    expect((rows.single['kcal_per_unit'] as num).toDouble(), 180);
    expect(rows.single['logged_at'], '2026-10-08T08:00:00+00:00');
    expect(harness.foods.entries, hasLength(1));
    expect(harness.foods.entries.single.loggedAt, DateTime(2026, 10, 8, 8));
    expect(harness.controller.foodEntries.map((entry) => entry.id), ['meal-a']);
    expect(
      harness.http.tables['food_entries']!.where(
        (row) => row['user_id'] == 'user-b',
      ),
      isEmpty,
    );
  });

  test('別アカウントの手元の同意では、写真も検索も関数を呼ばない', () async {
    AiDataConsent.override = null;
    SharedPreferences.setMockInitialValues({
      termsAgreementUserKey: 'user-a',
      aiDataConsentVersionKey: aiDataConsentVersion,
      aiDataConsentAtKey: '2026-10-10T00:00:00Z',
    });
    final preferences = await SharedPreferences.getInstance();
    final store = PrefsAiDataConsent(preferences);
    expect(await store.currentAgreementFor('user-b'), isFalse);
    expect(await store.currentAgreementFor('user-a'), isTrue);
    expect(store.isGranted, isTrue);
    expect(await store.sync(), isFalse);

    await expectLater(
      PhotoMealClient.supabase().analyze(
        jpeg: Uint8List(8),
        dishName: 'カレー',
        amount: '1皿',
      ),
      throwsA(isA<PhotoMealFailure>()),
    );
    await expectLater(
      AiFoodLookupClient.supabase().lookup('牛丼'),
      throwsA(isA<PhotoMealFailure>()),
    );
  });

  testWidgets('同意済みの起動と復帰は、ウィジェットと Siri を取り込む', (tester) async {
    final meals = _Meals('agreed-user')..add('widget-1');
    final siri = _Siri('agreed-user');
    final foods = _Foods();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'agreed-user', email: 'a@example.com'),
    );
    addTearDown(auth.dispose);
    AiDataConsent.override = MemoryAiDataConsent(
      serverByUser: {'agreed-user': aiDataConsentVersion},
    );
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: auth,
      dataSyncRepository: MockDataSyncRepository(),
      foodRepository: foods,
      lockScreenMealGateway: meals,
      siriVoiceGateway: siri,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.requiresTermsAgreement, isFalse);
    expect(controller.mayImportNativeMealQueues, isTrue);
    expect(meals.pending, isEmpty);
    expect(
      foods.entries.map((entry) => entry.id),
      containsAll(['widget-1', 'siri-1']),
    );

    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: OpenFoodFactsService(
          userAgent: OpenFoodFactsConfig.userAgent,
        ),
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: auth,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);

    meals.add('widget-2');
    final reads = meals.reads;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(meals.reads, greaterThan(reads));
    expect(foods.entries.map((entry) => entry.id), contains('widget-2'));
    expect(meals.pending, isEmpty);
  });

  testWidgets('iPad の同意画面は、指定の文があり、有料とは書かない', (tester) async {
    Future<void> pumpAt(Size size) async {
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      final controller = AppController();
      addTearDown(controller.dispose);
      final repository = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'new-user', email: 'a@example.com'),
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: const TextScaler.linear(1.35),
          ),
          child: MaterialApp(
            theme: AppTheme.light,
            home: TermsAgreementScreen(
              controller: controller,
              authenticationRepository: repository,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.termsConsentAi), findsOneWidget);
      expect(find.text(AppStrings.termsConsentUgc), findsOneWidget);
      expect(find.textContaining('有料'), findsNothing);
      expect(find.text(AppStrings.termsConsentAgree), findsOneWidget);
      expect(find.text(AppStrings.termsConsentDecline), findsOneWidget);
    }

    await pumpAt(const Size(1024, 1366));
    await pumpAt(const Size(1366, 1024));
  });
}

Map<String, Object> _localMeal(_Harness harness) {
  final entry = harness.foods.entries.single;
  return {
    'id': entry.id,
    'name': entry.name,
    'kcal': entry.kcalPerBase!.round(),
    'loggedAt': entry.loggedAt,
  };
}

class _Harness {
  _Harness({
    required this.http,
    required this.client,
    required this.foods,
    required this.session,
    required this.auth,
    required this.controller,
    required this.agreedFlag,
  });

  final SessionRlsPostgrest http;
  final SupabaseClient client;
  final _Foods foods;
  final LocalSessionStore session;
  final MockAuthenticationRepository auth;
  final AppController controller;
  final _Agreed agreedFlag;

  bool get agreed => agreedFlag.value;
  set agreed(bool value) => agreedFlag.value = value;

  static Future<_Harness> open() async {
    SharedPreferences.setMockInitialValues({
      'last_authenticated_user_id': 'user-a',
    });
    final preferences = await SharedPreferences.getInstance();
    final http = SessionRlsPostgrest('user-b');
    http.tables['users'] = [
      {
        'id': 'user-a',
        'email': 'a@example.com',
        'created_at': '2026-10-04T15:03:13.000+00:00',
      },
      {
        'id': 'user-b',
        'email': 'b@example.com',
        'created_at': '2026-10-04T15:03:13.000+00:00',
      },
    ];
    http.tables['app_settings'] = [
      {'user_id': 'user-a', 'onboarding_complete': true},
    ];
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: http,
    );
    final foods = _Foods()..entries.add(_meal('meal-a'));
    final agreedFlag = _Agreed();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-b', email: 'b@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: SupabaseDataSyncRepository(
        userRepository: _Users(),
        settingsRepository: _Settings(),
        foodRepository: foods,
        exerciseRepository: _Exercises(),
        alcoholRepository: _Alcohols(),
        weightRepository: _Weights(),
        client: client,
      ),
      localSessionStore: LocalSessionStore(preferences: preferences),
      localUserDataClearer: _Clearer(foods),
      userRepository: _Users(),
      settingsRepository: _Settings(),
      foodRepository: foods,
      termsAgreedFor: (_) async => agreedFlag.value,
    );
    return _Harness(
      http: http,
      client: client,
      foods: foods,
      session: LocalSessionStore(preferences: preferences),
      auth: auth,
      controller: controller,
      agreedFlag: agreedFlag,
    );
  }

  Future<void> dispose() async {
    controller.dispose();
    await auth.dispose();
    await client.dispose();
  }
}

class _Agreed {
  bool value = false;
}

FoodEntry _meal(String id) {
  return FoodEntry(
    id: id,
    name: '朝食',
    kcalPerBase: 180,
    proteinPerBase: 4,
    fatPerBase: 2,
    carbPerBase: 30,
    loggedAt: DateTime.utc(2026, 10, 8, 8),
  );
}

class _Clearer implements LocalUserDataClearerBase {
  _Clearer(this.foods);

  final _Foods foods;

  @override
  Future<void> clearAll() async {
    await foods.clearAll();
  }
}

class _Foods implements FoodRepositoryBase {
  final entries = <FoodEntry>[];

  @override
  Future<void> clearAll() async => entries.clear();

  @override
  Future<void> delete(String entryId) async =>
      entries.removeWhere((entry) => entry.id == entryId);

  @override
  Future<List<FoodEntry>> loadAll() async => List.of(entries);

  @override
  Future<void> save(FoodEntry entry) async {
    entries.removeWhere((existing) => existing.id == entry.id);
    entries.add(entry);
  }

  @override
  Future<void> saveAll(List<FoodEntry> values) async {
    for (final entry in values) {
      await save(entry);
    }
  }
}

class _Users implements UserRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<Goal?> loadGoal() async => null;

  @override
  Future<UserProfile?> loadProfile() async => null;

  @override
  Future<void> saveGoal(Goal value) async {}

  @override
  Future<void> saveProfile(UserProfile value) async {}
}

class _Settings implements SettingsRepositoryBase {
  AppSettings app = const AppSettings();

  @override
  Future<void> clearAll() async {
    app = const AppSettings();
  }

  @override
  Future<AppSettings> loadAppSettings() async => app;

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => null;

  @override
  Future<NutritionSettings?> loadNutritionSettings() async => null;

  @override
  Future<void> saveAppSettings(AppSettings settings) async => app = settings;

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {}

  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async {}
}

class _Exercises implements ExerciseRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<List<ExerciseEntry>> loadAll() async => const [];

  @override
  Future<void> save(ExerciseEntry entry) async {}

  @override
  Future<void> saveAll(List<ExerciseEntry> entries) async {}
}

class _Alcohols implements AlcoholRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<List<AlcoholEntry>> loadAll() async => const [];

  @override
  Future<void> save(AlcoholEntry entry) async {}

  @override
  Future<void> saveAll(List<AlcoholEntry> entries) async {}
}

class _Weights implements WeightRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<double?> latestWeight({WeightSource? preferredSource}) async => null;

  @override
  Future<List<WeightEntry>> loadAll() async => const [];

  @override
  Future<List<WeightRecord>> loadWeightRecords() async => const [];

  @override
  Future<void> save(WeightEntry entry) async {}

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {}
}

class _Meals implements LockScreenMealGateway {
  _Meals(this.ownerUserId);

  final String ownerUserId;
  final pending = <PendingLockScreenMeal>[];
  int reads = 0;

  void add(String id) {
    pending.add(
      PendingLockScreenMeal(
        registrationId: id,
        ownerUserId: ownerUserId,
        slot: 0,
        templateId: 'widget-meal-0',
        mealGroupId: 'group',
        mealGroupName: '朝',
        loggedAt: DateTime.utc(2026, 10, 8, 8),
        entries: [_meal(id)],
        surface: 'lock',
      ),
    );
  }

  @override
  Future<void> acknowledge(List<String> registrationIds) async {
    pending.removeWhere(
      (meal) => registrationIds.contains(meal.registrationId),
    );
  }

  @override
  Future<bool> isPaid() async => false;

  @override
  Future<LockScreenMealConfig> loadConfig() async =>
      LockScreenMealConfig.defaults();

  @override
  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot) async {}

  @override
  Future<List<PendingLockScreenMeal>> readPending() async {
    reads += 1;
    return List.of(pending);
  }

  @override
  Future<void> saveConfig(LockScreenMealConfig config) async {}

  @override
  Future<void> setPaid(bool isPaid) async {}
}

class _Siri implements SiriVoiceGateway {
  _Siri(String ownerUserId)
    : pending = SiriVoiceCodec.encodePending(
        ownerUserId: ownerUserId,
        food: _meal('siri-1'),
      );

  String pending;
  int reads = 0;

  @override
  Future<void> acknowledge(List<String> ids) async {
    if (ids.isNotEmpty) {
      pending = '[]';
    }
  }

  @override
  Future<void> publishCatalog(String catalogJson) async {}

  @override
  Future<String> readPending() async {
    reads += 1;
    return pending;
  }

  @override
  Future<String?> readOpenSearch() async => null;

  @override
  Future<void> clearOpenSearch() async {}
}
