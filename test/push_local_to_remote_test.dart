import 'dart:convert';

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
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/analytics/analytics_event.dart';
import 'package:ayg/services/local_user_data_clearer_base.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'helpers/analytics_test_support.dart';
import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a failed food push still sends exercise, weight, and alcohol',
    () async {
      final http = _TableHttp();
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: http,
      );
      addTearDown(client.dispose);
      final sync = SupabaseDataSyncRepository(
        userRepository: _Users(),
        settingsRepository: _Settings(),
        foodRepository: _Foods([_food('food-1')]),
        exerciseRepository: _Exercises([_exercise('exercise-1')]),
        alcoholRepository: _Alcohols([_alcohol('alcohol-1')]),
        weightRepository: _Weights([_weight('weight-1')]),
        client: client,
      );

      await expectLater(
        sync.pushLocalToRemote('user-1'),
        throwsA(
          isA<PartialPushException>().having(
            (error) => error.failures.map((failure) => failure.table).toList(),
            'tables',
            ['food_entries'],
          ),
        ),
      );

      expect(http.paths.where((path) => path.contains('food_entries')), isNotEmpty);
      expect(
        http.paths.where((path) => path.contains('exercise_entries')),
        isNotEmpty,
      );
      expect(
        http.paths.where((path) => path.contains('alcohol_entries')),
        isNotEmpty,
      );
      expect(
        http.paths.where((path) => path.contains('weight_entries')),
        isNotEmpty,
      );
      expect(http.failed.single, contains('food_entries'));
    },
  );

  test(
    'switching users records user_switch and the unsent record count',
    () async {
      final isarHarness = await setUpIsarHarness();
      final analytics = await AnalyticsHarness.open(isar: isarHarness.isar);
      addTearDown(() => Analytics.service = null);
      await analytics.service.grantConsent(surface: 'settings');
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString('last_authenticated_user_id', 'user-a');
      final pending = PendingRecordStore();
      await pending.markUpsert(PendingRecordKind.food, 'food-1');
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-b', email: 'b@example.com'),
      );
      final controller = AppController(
        authenticationRepository: auth,
        dataSyncRepository: MockDataSyncRepository(),
        localSessionStore: LocalSessionStore(preferences: preferences),
        localUserDataClearer: _Clearer(),
        pendingRecords: pending,
      );

      await controller.handleAuthenticatedSession();
      await analytics.service.settled;

      final cleared = [
        for (final row in await analytics.queue.all())
          AnalyticsEvent.decode(row.json),
      ].where((event) => event.eventName == 'local_data_cleared');
      expect(cleared, hasLength(1));
      expect(cleared.single.props['reason'], 'user_switch');
      expect(cleared.single.props['pending_records_count'], 1);
      expect(await pending.count(), 0);
      await auth.dispose();
    },
  );
}

class _TableHttp extends BaseClient {
  final paths = <String>[];
  final failed = <String>[];

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final path = request.url.path;
    paths.add(path);
    final food = path.contains('/food_entries');
    if (food) {
      failed.add(path);
    }
    final body = food
        ? utf8.encode('{"message":"food down","code":"500"}')
        : utf8.encode('[]');
    return StreamedResponse(
      Stream<List<int>>.value(body),
      food ? 500 : 201,
      request: request,
      headers: {'content-type': 'application/json'},
    );
  }

  @override
  void close() {}
}

class _Users implements UserRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<Goal?> loadGoal() async => null;

  @override
  Future<UserProfile?> loadProfile() async => null;

  @override
  Future<void> saveGoal(Goal goal) async {}

  @override
  Future<void> saveProfile(UserProfile profile) async {}
}

class _Settings implements SettingsRepositoryBase {
  @override
  Future<void> clearAll() async {}

  @override
  Future<AppSettings> loadAppSettings() async => const AppSettings();

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => null;

  @override
  Future<NutritionSettings?> loadNutritionSettings() async => null;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {}

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {}

  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async {}
}

class _Foods implements FoodRepositoryBase {
  _Foods(this.entries);

  final List<FoodEntry> entries;

  @override
  Future<void> clearAll() async => entries.clear();

  @override
  Future<void> delete(String entryId) async =>
      entries.removeWhere((entry) => entry.id == entryId);

  @override
  Future<List<FoodEntry>> loadAll() async => entries;

  @override
  Future<void> save(FoodEntry entry) async {}

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {}
}

class _Exercises implements ExerciseRepositoryBase {
  _Exercises(this.entries);

  final List<ExerciseEntry> entries;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<List<ExerciseEntry>> loadAll() async => entries;

  @override
  Future<void> save(ExerciseEntry entry) async {}

  @override
  Future<void> saveAll(List<ExerciseEntry> entries) async {}
}

class _Alcohols implements AlcoholRepositoryBase {
  _Alcohols(this.entries);

  final List<AlcoholEntry> entries;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<List<AlcoholEntry>> loadAll() async => entries;

  @override
  Future<void> save(AlcoholEntry entry) async {}

  @override
  Future<void> saveAll(List<AlcoholEntry> entries) async {}
}

class _Weights implements WeightRepositoryBase {
  _Weights(this.entries);

  final List<WeightEntry> entries;

  @override
  Future<void> clearAll() async {}

  @override
  Future<void> delete(String entryId) async {}

  @override
  Future<double?> latestWeight({WeightSource? preferredSource}) async => null;

  @override
  Future<List<WeightEntry>> loadAll() async => entries;

  @override
  Future<List<WeightRecord>> loadWeightRecords() async => const [];

  @override
  Future<void> save(WeightEntry entry) async {}

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {}
}

class _Clearer implements LocalUserDataClearerBase {
  @override
  Future<void> clearAll() async {}
}

FoodEntry _food(String id) {
  return FoodEntry(
    id: id,
    name: 'ごはん',
    quantity: 1,
    loggedAt: DateTime(2026, 10, 7, 12),
  );
}

ExerciseEntry _exercise(String id) {
  return ExerciseEntry(
    id: id,
    name: '歩行',
    durationMin: 20,
    burnedKcal: 80,
    loggedAt: DateTime(2026, 10, 7, 12),
  );
}

AlcoholEntry _alcohol(String id) {
  return AlcoholEntry(
    id: id,
    beverageName: 'ビール',
    amount: 350,
    unit: 'ml',
    alcoholPercentage: 5,
    totalCalories: 140,
    pureAlcoholGrams: 14,
    alcoholCalories: 98,
    consumedAt: DateTime(2026, 10, 7, 12),
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
