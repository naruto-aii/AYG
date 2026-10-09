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
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import 'mocks/mock_authentication_repository.dart';

/// build 9: 同じ Apple ID でログアウト→ログインし直すと、初回設定（Health・
/// プロフィール・目標）からやり直しになった。ログアウトで手元を消したあと、
/// 取得の前の送信で「初回設定 未完了」をサーバへ書き、サーバの「完了」を
/// 上書きしていた。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    're-login restores onboarding, profile and goal from the server',
    () async {
      final server = _Server()
        ..rows['app_settings'] = {
          'user_id': 'user-1',
          'onboarding_complete': true,
        }
        ..rows['profiles'] = {
          'user_id': 'user-1',
          'birth_date': '1990-04-01',
          'gender': 'male',
          'height_cm': 172,
          'weight_kg': 68.5,
          'display_name': 'なると',
        }
        ..rows['goals'] = {
          'user_id': 'user-1',
          'goal_type': 'lose',
          'target_weight_kg': 64,
          'target_date': '2027-03-01',
          'goal_pace': 'standard',
        };
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-anon-key',
        httpClient: server,
      );
      addTearDown(client.dispose);

      // ログアウト直後の端末: 手元は空。
      final users = _Users();
      final settings = _Settings();
      final sync = SupabaseDataSyncRepository(
        userRepository: users,
        settingsRepository: settings,
        foodRepository: _Foods(),
        exerciseRepository: _Exercises(),
        alcoholRepository: _Alcohols(),
        weightRepository: _Weights(),
        client: client,
      );
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      addTearDown(auth.dispose);
      final controller = AppController(
        authenticationRepository: auth,
        dataSyncRepository: sync,
        userRepository: users,
        settingsRepository: settings,
        termsAgreed: () async => true,
      );

      await controller.handleAuthenticatedSession();

      expect(controller.lastSyncFailed, isFalse);
      expect(
        server.rows['app_settings']!['onboarding_complete'],
        isTrue,
        reason: 'サーバの「初回設定 完了」を上書きしない',
      );
      expect(controller.onboardingComplete, isTrue);
      expect(controller.requiresOnboarding, isFalse);
      expect(controller.profile?.heightCm, 172);
      expect(controller.profile?.displayName, 'なると');
      expect(controller.goal?.targetWeightKg, 64);
    },
  );

  test('a completed onboarding is still sent to the server', () async {
    final server = _Server();
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      httpClient: server,
    );
    addTearDown(client.dispose);
    final settings = _Settings()
      ..app = const AppSettings(onboardingComplete: true);
    final sync = SupabaseDataSyncRepository(
      userRepository: _Users(),
      settingsRepository: settings,
      foodRepository: _Foods(),
      exerciseRepository: _Exercises(),
      alcoholRepository: _Alcohols(),
      weightRepository: _Weights(),
      client: client,
    );

    await sync.pushLocalToRemote('user-1');

    expect(server.rows['app_settings']?['onboarding_complete'], isTrue);
  });
}

/// 1ユーザー分の表を持つだけの PostgREST もどき。
class _Server extends BaseClient {
  final rows = <String, Map<String, dynamic>>{
    'users': {
      'id': 'user-1',
      'email': 'a@example.com',
      'created_at': '2026-10-04T15:03:13Z',
    },
  };

  @override
  Future<StreamedResponse> send(BaseRequest request) async {
    final table = request.url.pathSegments.last;
    Object? body = <Object>[];
    if (request.method == 'GET') {
      final row = rows[table];
      body = row == null ? <Object>[] : [row];
    } else if (request.method == 'POST' && request is Request) {
      final sent = jsonDecode(request.body);
      final list = sent is List ? sent : [sent];
      if (list.isNotEmpty &&
          const {
            'app_settings',
            'profiles',
            'goals',
            'nutrition_settings',
            'health_snapshots',
          }.contains(table)) {
        rows[table] = {...?rows[table], ...(list.last as Map<String, dynamic>)};
      }
      body = list;
    }
    final wantsObject = (request.headers['Accept'] ?? '').contains(
      'vnd.pgrst.object',
    );
    if (wantsObject && body is List) {
      body = body.isEmpty ? rows['users'] : body.first;
    }
    return StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(body))),
      200,
      request: request,
      headers: {'content-type': 'application/json'},
    );
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
  Future<void> save(FoodEntry entry) async => entries.add(entry);

  @override
  Future<void> saveAll(List<FoodEntry> values) async => entries.addAll(values);
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
