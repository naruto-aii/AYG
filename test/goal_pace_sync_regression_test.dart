@Tags(['integration'])
library;

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/calculation/goal_pace.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/platform/web/repositories/web_user_repository.dart'
    as web_user;
import 'package:ayg/repositories/contracts/alcohol_repository_base.dart';
import 'package:ayg/repositories/contracts/exercise_repository_base.dart';
import 'package:ayg/repositories/contracts/food_repository_base.dart';
import 'package:ayg/repositories/contracts/settings_repository_base.dart';
import 'package:ayg/repositories/contracts/user_repository_base.dart';
import 'package:ayg/repositories/contracts/weight_repository_base.dart';
import 'package:ayg/repositories/data_sync_repository.dart';
import 'package:ayg/services/energy_target_calculation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase/supabase.dart';

import 'helpers/isar_test_helper.dart';
import 'supabase_saved_food_repository_integration_test.dart'
    show createAuthenticatedClient, isLocalSupabaseAvailable;

const _localUrl = 'http://127.0.0.1:54321';
const _serviceKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU';

/// [_pushGoal] と同じリモート値。
String? remoteGoalPaceValue(Goal goal) {
  if (goal.type == GoalType.maintain) {
    return null;
  }
  return goal.goalPace.name;
}

/// [_pullGoal] と同じローカル変換。
GoalPace goalPaceFromRemoteRow(Map<String, dynamic> row) {
  return row.containsKey('goal_pace')
      ? GoalPace.fromName(row['goal_pace'] as String?)
      : GoalPace.standard;
}

Goal sampleLoseGoal({GoalPace pace = GoalPace.standard}) {
  return Goal(
    type: GoalType.lose,
    targetWeightKg: 68,
    targetDate: DateTime(2026, 12, 31),
    goalPace: pace,
  );
}

SupabaseDataSyncRepository buildGoalSync({
  required SupabaseClient client,
  required UserRepositoryBase userRepository,
}) {
  return SupabaseDataSyncRepository(
    userRepository: userRepository,
    settingsRepository: _NoopSettingsRepository(),
    foodRepository: _NoopFoodRepository(),
    exerciseRepository: _NoopExerciseRepository(),
    alcoholRepository: _NoopAlcoholRepository(),
    weightRepository: _NoopWeightRepository(),
    client: client,
  );
}

void main() {
  group('GoalPace sync contract', () {
    test('push maps maintain to null and lose/gain to slow/standard', () {
      expect(
        remoteGoalPaceValue(
          sampleLoseGoal(pace: GoalPace.slow),
        ),
        'slow',
      );
      expect(
        remoteGoalPaceValue(
          sampleLoseGoal(pace: GoalPace.standard),
        ),
        'standard',
      );
      expect(
        remoteGoalPaceValue(
          Goal(
            type: GoalType.maintain,
            targetWeightKg: 70,
            targetDate: DateTime(2026, 12, 31),
            goalPace: GoalPace.slow,
          ),
        ),
        isNull,
      );
    });

    test('pull falls back null and unknown to standard', () {
      expect(
        goalPaceFromRemoteRow({
          'goal_type': 'lose',
          'goal_pace': null,
        }),
        GoalPace.standard,
      );
      expect(
        goalPaceFromRemoteRow({
          'goal_type': 'lose',
          'goal_pace': 'unknown',
        }),
        GoalPace.standard,
      );
      expect(
        goalPaceFromRemoteRow({
          'goal_type': 'lose',
          'goal_pace': 'slow',
        }),
        GoalPace.slow,
      );
      expect(
        goalPaceFromRemoteRow({'goal_type': 'lose'}),
        GoalPace.standard,
      );
    });

    test('slow pace raises lose target kcal versus standard', () {
      const service = EnergyTargetCalculationService();
      final profile = UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 75,
      );
      const settings = NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      );
      final referenceDate = DateTime(2026, 7, 21);
      final goal = sampleLoseGoal();

      final standard = service.calculate(
        profile: profile,
        goal: goal.copyWith(goalPace: GoalPace.standard),
        settings: settings,
        goalPace: GoalPace.standard,
        referenceDate: referenceDate,
      );
      final slow = service.calculate(
        profile: profile,
        goal: goal.copyWith(goalPace: GoalPace.slow),
        settings: settings,
        goalPace: GoalPace.slow,
        referenceDate: referenceDate,
      );

      expect(
        slow.goalFoodTargetKcal,
        greaterThan(standard.goalFoodTargetKcal!),
      );
      expect(slow.dailyGoalAdjustmentKcal, isNot(0));
    });

    test('maintain keeps zero pace adjustment', () {
      const service = EnergyTargetCalculationService();
      final result = service.calculate(
        profile: UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 175,
          weightKg: 75,
        ),
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: DateTime(2026, 12, 31),
          goalPace: GoalPace.slow,
        ),
        settings: const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
        goalPace: GoalPace.slow,
        referenceDate: DateTime(2026, 7, 21),
      );

      expect(result.dailyGoalAdjustmentKcal, 0);
    });
  });

  group('GoalPace local persistence regression', () {
    test('Isar save and reload keeps pace', () async {
      final harness = await setUpIsarHarness();
      addTearDown(harness.dispose);

      await harness.userRepository.saveGoal(sampleLoseGoal(pace: GoalPace.slow));
      expect(
        (await harness.userRepository.loadGoal())?.goalPace,
        GoalPace.slow,
      );
    });

    test('logout clear and simulated relogin pull restore pace', () async {
      final harness = await setUpIsarHarness();
      addTearDown(harness.dispose);

      await harness.userRepository.saveGoal(sampleLoseGoal(pace: GoalPace.slow));
      await harness.userRepository.clearAll();

      final remoteRow = {
        'goal_type': 'lose',
        'target_weight_kg': 68,
        'target_date': '2026-12-31T00:00:00.000Z',
        'goal_pace': 'slow',
      };
      await harness.userRepository.saveGoal(
        Goal(
          type: GoalType.lose,
          targetWeightKg: (remoteRow['target_weight_kg'] as num).toDouble(),
          targetDate: DateTime.parse(remoteRow['target_date'] as String),
          goalPace: goalPaceFromRemoteRow(remoteRow),
        ),
      );

      expect(
        (await harness.userRepository.loadGoal())?.goalPace,
        GoalPace.slow,
      );
    });

    test('web reload pull restores pace from remote row', () async {
      final repo = web_user.UserRepository();
      await repo.clearAll();

      final remoteRow = {
        'goal_type': 'gain',
        'target_weight_kg': 78,
        'target_date': '2026-12-31T00:00:00.000Z',
        'goal_pace': 'standard',
      };
      await repo.saveGoal(
        Goal(
          type: GoalType.gain,
          targetWeightKg: (remoteRow['target_weight_kg'] as num).toDouble(),
          targetDate: DateTime.parse(remoteRow['target_date'] as String),
          goalPace: goalPaceFromRemoteRow(remoteRow),
        ),
      );

      expect((await repo.loadGoal())?.goalPace, GoalPace.standard);
    });

    test('legacy null remote pace defaults to standard after reload', () async {
      final harness = await setUpIsarHarness();
      addTearDown(harness.dispose);

      await harness.userRepository.saveGoal(
        Goal(
          type: GoalType.lose,
          targetWeightKg: 68,
          targetDate: DateTime(2026, 12, 31),
          goalPace: goalPaceFromRemoteRow({
            'goal_type': 'lose',
            'goal_pace': null,
          }),
        ),
      );

      expect(
        (await harness.userRepository.loadGoal())?.goalPace,
        GoalPace.standard,
      );
    });
  });

  group('GoalPace Supabase integration', () {
    late SupabaseClient service;
    late bool available;

    setUpAll(() async {
      available = await isLocalSupabaseAvailable();
      if (!available) {
        return;
      }
      service = SupabaseClient(_localUrl, _serviceKey);
    });

    test('push pull round-trip and RLS isolation', () async {
      if (!available) {
        markTestSkipped('Local Supabase not available');
      }

      late SupabaseClient ownerClient;
      late SupabaseClient otherClient;
      try {
        final suffix = DateTime.now().microsecondsSinceEpoch;
        ownerClient = await createAuthenticatedClient(
          service: service,
          email: 'goal-pace-owner-$suffix@test.local',
          password: 'test-password-123',
        );
        otherClient = await createAuthenticatedClient(
          service: service,
          email: 'goal-pace-other-$suffix@test.local',
          password: 'test-password-123',
        );
      } catch (_) {
        markTestSkipped('Local Supabase auth unavailable');
        return;
      }

      final ownerId = ownerClient.auth.currentUser!.id;

      final ownerRepo = _MemoryUserRepository(
        initialGoal: sampleLoseGoal(pace: GoalPace.slow),
      );
      final ownerSync = buildGoalSync(
        client: ownerClient,
        userRepository: ownerRepo,
      );
      await ownerSync.pushLocalToRemote(ownerId);

      final remoteRow = await ownerClient
          .from('goals')
          .select()
          .eq('user_id', ownerId)
          .single();
      expect(remoteRow['goal_pace'], 'slow');

      final reloadRepo = _MemoryUserRepository();
      final reloadSync = buildGoalSync(
        client: ownerClient,
        userRepository: reloadRepo,
      );
      await reloadSync.pullRemoteToLocal(ownerId);
      expect((await reloadRepo.loadGoal())?.goalPace, GoalPace.slow);

      await expectLater(
        otherClient
            .from('goals')
            .update({'goal_pace': 'standard'})
            .eq('user_id', ownerId)
            .select(),
        completion(isEmpty),
      );

      final maintainRepo = _MemoryUserRepository(
        initialGoal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 70,
          targetDate: DateTime(2026, 12, 31),
          goalPace: GoalPace.slow,
        ),
      );
      final maintainSync = buildGoalSync(
        client: ownerClient,
        userRepository: maintainRepo,
      );
      await maintainSync.pushLocalToRemote(ownerId);
      final maintainRow = await ownerClient
          .from('goals')
          .select('goal_pace')
          .eq('user_id', ownerId)
          .single();
      expect(maintainRow['goal_pace'], isNull);
    });
  });
}

class _MemoryUserRepository implements UserRepositoryBase {
  _MemoryUserRepository({Goal? initialGoal}) : _goal = initialGoal;

  Goal? _goal;

  @override
  Future<void> saveGoal(Goal goal) async {
    _goal = goal;
  }

  @override
  Future<Goal?> loadGoal() async => _goal;

  @override
  Future<void> clearAll() async {
    _goal = null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopSettingsRepository implements SettingsRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopFoodRepository implements FoodRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopExerciseRepository implements ExerciseRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopAlcoholRepository implements AlcoholRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopWeightRepository implements WeightRepositoryBase {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
