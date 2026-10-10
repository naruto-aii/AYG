import 'package:ayg/app.dart';
import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/app_settings.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
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
import 'package:ayg/repositories/pending_record_store.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/local_user_data_clearer_base.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/siri_voice_gateway.dart';
import 'package:ayg/services/siri_voice_log.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'helpers/fake_postgrest.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AiDataConsent previous;
  setUp(() {
    previous = AiDataConsent.override!;
  });
  tearDown(() {
    AiDataConsent.override = previous;
  });

  test('同意しないと手元の食事は残り、送られない', () async {
    final foods = _Foods()..entries.add(_meal('meal-a'));
    final pending = PendingRecordStore();
    await pending.markUpsert(PendingRecordKind.food, 'meal-a');
    final session = await _session('user-a');
    final sync = _RecordingSync(foods);
    final clearer = _Clearer(foods);
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-a', email: 'a@example.com'),
    );
    addTearDown(auth.dispose);
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: sync,
      localSessionStore: session,
      localUserDataClearer: clearer,
      foodRepository: foods,
      pendingRecords: pending,
      termsAgreedFor: (_) async => false,
    );

    await controller.handleAuthenticatedSession();
    expect(controller.requiresTermsAgreement, isTrue);
    expect(sync.pushes, isEmpty);

    final left = await controller.declineTermsAgreement();

    expect(left, isTrue);
    expect(controller.isAuthenticated, isFalse);
    expect(sync.pushes, isEmpty);
    expect(clearer.calls, 0);
    expect(foods.entries.map((entry) => entry.id), ['meal-a']);
    expect(await pending.count(), 1);
    expect(await session.loadLastUserId(), 'user-a');
  });

  test('別アカウントの未送信は、今のユーザーとしては送られない', () async {
    final foods = _Foods()..entries.add(_meal('meal-a'));
    final session = await _session('user-a');
    final sync = _RecordingSync(foods);
    final clearer = _Clearer(foods);
    var agreed = false;
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-b', email: 'b@example.com'),
    );
    addTearDown(auth.dispose);
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: sync,
      localSessionStore: session,
      localUserDataClearer: clearer,
      foodRepository: foods,
      termsAgreedFor: (_) async => agreed,
    );

    await controller.handleAuthenticatedSession();
    expect(await controller.declineTermsAgreement(), isTrue);
    expect(sync.pushes, isEmpty);
    expect(foods.entries.map((entry) => entry.id), ['meal-a']);
    expect(await session.loadLastUserId(), 'user-a');

    agreed = true;
    auth.setCurrentUser(const AuthUser(id: 'user-b', email: 'b@example.com'));
    await controller.handleAuthenticatedSession();

    expect(sync.pushes.map((push) => push.userId), ['user-a', 'user-b']);
    expect(sync.pushes.first.foodIds, ['meal-a']);
    expect(sync.pushes.last.foodIds, isEmpty);
    expect(foods.entries, isEmpty);
    expect(clearer.calls, 1);
  });

  test('同じアカウントで入り直すと食事が残り、未完了の初回設定は送られない', () async {
    SharedPreferences.setMockInitialValues({
      'last_authenticated_user_id': 'user-a',
    });
    final preferences = await SharedPreferences.getInstance();
    final http = FakePostgrest();
    http.tables['users'] = [
      {
        'id': 'user-a',
        'email': 'a@example.com',
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
    addTearDown(client.dispose);
    final foods = _Foods()..entries.add(_meal('meal-a'));
    final settings = _Settings();
    final sync = SupabaseDataSyncRepository(
      userRepository: _Users(),
      settingsRepository: settings,
      foodRepository: foods,
      exerciseRepository: _Exercises(),
      alcoholRepository: _Alcohols(),
      weightRepository: _Weights(),
      client: client,
    );
    var agreed = false;
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-a', email: 'a@example.com'),
    );
    addTearDown(auth.dispose);
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: sync,
      localSessionStore: LocalSessionStore(preferences: preferences),
      userRepository: _Users(),
      settingsRepository: settings,
      foodRepository: foods,
      termsAgreedFor: (_) async => agreed,
    );

    await controller.handleAuthenticatedSession();
    expect(await controller.declineTermsAgreement(), isTrue);
    expect(http.requests.where((path) => path.startsWith('POST')), isEmpty);
    expect(foods.entries.map((entry) => entry.id), ['meal-a']);
    expect(http.tables['app_settings']!.single['onboarding_complete'], isTrue);

    agreed = true;
    auth.setCurrentUser(const AuthUser(id: 'user-a', email: 'a@example.com'));
    await controller.handleAuthenticatedSession();

    expect(controller.lastSyncFailed, isFalse);
    expect(controller.onboardingComplete, isTrue);
    expect(settings.app.onboardingComplete, isTrue);
    expect(http.tables['app_settings']!.single['onboarding_complete'], isTrue);
    expect(
      http.requests.where((path) => path.startsWith('POST /app_settings')),
      isEmpty,
    );
    final sent = http.tables['food_entries'] ?? const [];
    expect(sent, isNotEmpty);
    expect(sent.every((row) => row['user_id'] == 'user-a'), isTrue);
    expect(foods.entries.map((entry) => entry.id), ['meal-a']);
    expect(controller.foodEntries.map((entry) => entry.id), ['meal-a']);
  });

  testWidgets('同意の前はウィジェットと Siri の待ち行列を取り込まない', (tester) async {
    final meals = _Meals('queue-user')..add('widget-1');
    final siri = _Siri('queue-user');
    final foods = _Foods();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'queue-user', email: 'q@example.com'),
    );
    addTearDown(auth.dispose);
    AiDataConsent.override = MemoryAiDataConsent(serverByUser: {});
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: auth,
      dataSyncRepository: MockDataSyncRepository(),
      foodRepository: foods,
      lockScreenMealGateway: meals,
      siriVoiceGateway: siri,
    );

    await controller.initialize();
    expect(meals.reads, 0);
    expect(siri.reads, 0);
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

    expect(meals.setPaidCalls, greaterThanOrEqualTo(2));
    expect(meals.reads, 0);
    expect(meals.acks, 0);
    expect(siri.reads, 0);
    expect(siri.acks, 0);
    expect(foods.entries, isEmpty);
    expect(controller.mayImportNativeMealQueues, isFalse);

    await tester.tap(find.text(AppStrings.termsConsentAgree));
    await tester.pumpAndSettle();

    expect(controller.mayImportNativeMealQueues, isTrue);
    expect(meals.reads, greaterThan(0));
    expect(siri.reads, greaterThan(0));
    expect(meals.acks, greaterThan(0));
    expect(
      foods.entries.map((entry) => entry.id),
      containsAll(['widget-1', 'siri-1']),
    );
    expect(meals.pending, isEmpty);

    final reads = meals.reads;
    final paid = meals.setPaidCalls;
    meals.add('widget-2');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(meals.setPaidCalls, greaterThan(paid));
    expect(meals.reads, greaterThan(reads));
    expect(foods.entries.map((entry) => entry.id), contains('widget-2'));
  });
}

Future<LocalSessionStore> _session(String userId) async {
  SharedPreferences.setMockInitialValues({
    'last_authenticated_user_id': userId,
  });
  final preferences = await SharedPreferences.getInstance();
  return LocalSessionStore(preferences: preferences);
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

class _RecordingSync extends MockDataSyncRepository {
  _RecordingSync(this.foods);

  final _Foods foods;
  final pushes = <({String userId, List<String> foodIds})>[];

  @override
  Future<void> pushLocalToRemote(String userId) async {
    pushLocalToRemoteCalled = true;
    lastUserId = userId;
    pushes.add((
      userId: userId,
      foodIds: [for (final entry in await foods.loadAll()) entry.id],
    ));
  }
}

class _Clearer implements LocalUserDataClearerBase {
  _Clearer(this.foods);

  final _Foods foods;
  int calls = 0;

  @override
  Future<void> clearAll() async {
    calls += 1;
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
  UserProfile? profile;
  Goal? goal;

  @override
  Future<void> clearAll() async {
    profile = null;
    goal = null;
  }

  @override
  Future<Goal?> loadGoal() async => goal;

  @override
  Future<UserProfile?> loadProfile() async => profile;

  @override
  Future<void> saveGoal(Goal value) async => goal = value;

  @override
  Future<void> saveProfile(UserProfile value) async => profile = value;
}

class _Settings implements SettingsRepositoryBase {
  AppSettings app = const AppSettings();
  NutritionSettings? nutrition;
  HealthSnapshot? health;

  @override
  Future<void> clearAll() async {
    app = const AppSettings();
    nutrition = null;
    health = null;
  }

  @override
  Future<AppSettings> loadAppSettings() async => app;

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => health;

  @override
  Future<NutritionSettings?> loadNutritionSettings() async => nutrition;

  @override
  Future<void> saveAppSettings(AppSettings settings) async => app = settings;

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async =>
      health = snapshot;

  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async =>
      nutrition = settings;
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
  int acks = 0;
  int setPaidCalls = 0;

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
    acks += registrationIds.length;
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
  Future<void> setPaid(bool isPaid) async {
    setPaidCalls += 1;
  }
}

class _Siri implements SiriVoiceGateway {
  _Siri(String ownerUserId)
    : pending = SiriVoiceCodec.encodePending(
        ownerUserId: ownerUserId,
        food: _meal('siri-1'),
      );

  String pending;
  int reads = 0;
  int acks = 0;

  @override
  Future<void> acknowledge(List<String> ids) async {
    acks += ids.length;
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
