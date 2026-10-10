import 'dart:async';

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
import 'package:ayg/services/local_user_data_clearer_base.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'helpers/fake_postgrest.dart';
import 'mocks/mock_authentication_repository.dart';

const _userA = 'user-a';
const _userB = 'user-b';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a background push overlapped by logout does not send the next person as the previous id',
    () async {
      final harness = await _Harness.open();
      addTearDown(harness.close);
      await harness.signIn(_userA);

      harness.food.entries.add(_meal('meal-a', '前の人の食事'));
      await harness.pending.markUpsert(PendingRecordKind.food, 'meal-a');
      final gate = harness.food.holdNextRead();
      harness.controller.setProfile(_profile());
      await _until(
        () => gate.started.isCompleted,
        'background push did not reach the food read',
      );

      final left = await harness.controller.logout();
      expect(left, isTrue);
      expect(harness.auth.currentUser, isNull);

      harness.auth.setCurrentUser(
        const AuthUser(id: _userB, email: 'b@example.com'),
      );
      harness.seedUser(_userB);
      await harness.controller.handleAuthenticatedSession();
      harness.food.entries.add(_meal('meal-b', '次の人の食事'));
      gate.release();

      await _settle();
      expect(
        _rowsFor(harness.server, userId: _userA, entryId: 'meal-b'),
        isEmpty,
      );
      expect(
        _rowsFor(harness.server, userId: _userA, entryId: 'meal-a'),
        isNotEmpty,
      );
    },
  );

  test(
    'the same person keeps an unsent meal and a background push delivers it',
    () async {
      final harness = await _Harness.open();
      addTearDown(harness.close);
      await harness.signIn(_userA);

      harness.food.entries.add(_meal('meal-keep', 'いつもの食事'));
      await harness.pending.markUpsert(PendingRecordKind.food, 'meal-keep');
      harness.controller.setProfile(_profile());
      await _settle();

      expect(
        _rowsFor(harness.server, userId: _userA, entryId: 'meal-keep'),
        isNotEmpty,
      );
      expect(harness.controller.hasUnsentRecords, isFalse);
      expect(await harness.pending.count(), 0);
    },
  );

  test(
    'a background push discarded after the generation moves is sent again',
    () async {
      final harness = await _Harness.open();
      addTearDown(harness.close);
      await harness.signIn(_userA);

      harness.food.entries.add(_meal('meal-again', '送り直す食事'));
      await harness.pending.markUpsert(PendingRecordKind.food, 'meal-again');
      final gate = harness.food.holdNextRead();
      harness.controller.setProfile(_profile());
      await _until(
        () => gate.started.isCompleted,
        'background push did not reach the food read',
      );

      final profilesWhileHeld = _posts(harness.server, 'profiles');
      expect(profilesWhileHeld, 1);
      await harness.controller.handleAuthenticatedSession();
      expect(
        _rowsFor(harness.server, userId: _userA, entryId: 'meal-again'),
        isEmpty,
      );
      gate.release();
      await _settle();

      expect(
        _posts(harness.server, 'profiles'),
        greaterThan(profilesWhileHeld),
      );
      expect(
        _rowsFor(harness.server, userId: _userA, entryId: 'meal-again'),
        isNotEmpty,
      );
      expect(harness.controller.hasUnsentRecords, isFalse);
      expect(await harness.pending.count(), 0);
    },
  );
}

int _posts(FakePostgrest server, String table) {
  return server.requests
      .where((request) => request.startsWith('POST /$table?'))
      .length;
}

List<Map<String, dynamic>> _rowsFor(
  FakePostgrest server, {
  required String userId,
  required String entryId,
}) {
  return [
    for (final row in server.rows('food_entries'))
      if (row['user_id'] == userId && row['entry_id'] == entryId) row,
  ];
}

Future<void> _until(bool Function() done, String reason) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(done(), isTrue, reason: reason);
}

Future<void> _settle() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

FoodEntry _meal(String id, String name) {
  return FoodEntry(
    id: id,
    name: name,
    quantity: 1,
    loggedAt: DateTime(2026, 10, 7, 12),
  );
}

UserProfile _profile() {
  return UserProfile(
    birthDate: DateTime(1990, 1, 1),
    gender: Gender.female,
    heightCm: 160,
    weightKg: 55,
    displayName: '利用者',
  );
}

class _ReadGate {
  final started = Completer<void>();
  final _release = Completer<void>();

  void release() {
    if (!_release.isCompleted) {
      _release.complete();
    }
  }

  Future<void> get future => _release.future;
}

class _Harness {
  _Harness({
    required this.auth,
    required this.food,
    required this.server,
    required this.client,
    required this.controller,
    required this.pending,
  });

  final MockAuthenticationRepository auth;
  final _HoldingFoods food;
  final FakePostgrest server;
  final SupabaseClient client;
  final AppController controller;
  final PendingRecordStore pending;

  static Future<_Harness> open() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: _userA, email: 'a@example.com'),
    );
    final food = _HoldingFoods();
    final users = _Users();
    final settings = _Settings();
    final server = FakePostgrest();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: server,
    );
    final pending = PendingRecordStore();
    final sync = SupabaseDataSyncRepository(
      userRepository: users,
      settingsRepository: settings,
      foodRepository: food,
      exerciseRepository: _Exercises(),
      alcoholRepository: _Alcohols(),
      weightRepository: _Weights(),
      client: client,
      pendingRecords: pending,
    );
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: sync,
      localSessionStore: LocalSessionStore(preferences: preferences),
      localUserDataClearer: _Clearer(),
      userRepository: users,
      settingsRepository: settings,
      foodRepository: food,
      pendingRecords: pending,
      termsAgreedFor: (_) async => true,
    );
    return _Harness(
      auth: auth,
      food: food,
      server: server,
      client: client,
      controller: controller,
      pending: pending,
    );
  }

  void seedUser(String userId) {
    server.rows('users').add({
      'id': userId,
      'email': '$userId@example.com',
      'created_at': '2026-01-01T00:00:00.000+00:00',
    });
  }

  Future<void> signIn(String userId) async {
    seedUser(userId);
    await controller.handleAuthenticatedSession();
    expect(controller.hasInitialSyncCompleted, isTrue, reason: userId);
  }

  Future<void> close() async {
    controller.dispose();
    await auth.dispose();
    client.dispose();
  }
}

class _HoldingFoods implements FoodRepositoryBase {
  final entries = <FoodEntry>[];
  _ReadGate? _gate;

  _ReadGate holdNextRead() {
    final gate = _ReadGate();
    _gate = gate;
    return gate;
  }

  @override
  Future<List<FoodEntry>> loadAll() async {
    final gate = _gate;
    if (gate != null) {
      _gate = null;
      if (!gate.started.isCompleted) {
        gate.started.complete();
      }
      await gate.future;
    }
    return List<FoodEntry>.from(entries);
  }

  @override
  Future<void> save(FoodEntry entry) async {
    entries.removeWhere((item) => item.id == entry.id);
    entries.add(entry);
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<void> delete(String entryId) async {
    entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    entries.clear();
  }
}

class _Users implements UserRepositoryBase {
  UserProfile? profile;

  @override
  Future<void> clearAll() async {
    profile = null;
  }

  @override
  Future<Goal?> loadGoal() async => null;

  @override
  Future<UserProfile?> loadProfile() async => profile;

  @override
  Future<void> saveGoal(Goal goal) async {}

  @override
  Future<void> saveProfile(UserProfile profile) async {
    this.profile = profile;
  }
}

class _Settings implements SettingsRepositoryBase {
  AppSettings appSettings = const AppSettings();

  @override
  Future<void> clearAll() async {
    appSettings = const AppSettings();
  }

  @override
  Future<AppSettings> loadAppSettings() async => appSettings;

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => null;

  @override
  Future<NutritionSettings?> loadNutritionSettings() async => null;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    appSettings = settings;
  }

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

class _Clearer implements LocalUserDataClearerBase {
  @override
  Future<void> clearAll() async {}
}
