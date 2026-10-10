import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_level.dart';
import '../models/alcohol_entry.dart';
import '../models/app_settings.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/meal_template.dart';
import '../models/calculation/calorie_target_mode.dart';
import '../models/calculation/goal_pace.dart';
import '../models/goal.dart';
import '../models/health_profile_data.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import 'contracts/alcohol_repository_base.dart';
import 'contracts/exercise_repository_base.dart';
import 'contracts/food_repository_base.dart';
import '../models/workout_template.dart';
import 'contracts/workout_template_repository_base.dart';
import 'contracts/settings_repository_base.dart';
import 'contracts/user_repository_base.dart';
import 'contracts/weight_repository_base.dart';
import '../models/health_profile_data.dart';
import '../models/sync_failure.dart';
import '../services/health_workout_sync.dart';
import '../utils/local_date.dart';
import 'food_master_repositories.dart';
import 'health_repository.dart';
import 'supabase/exercise_entry_row_mapper.dart';
import 'supabase/food_master_row_mapper.dart';
import 'supabase/supabase_workout_template_repository.dart';
import 'alcohol_repository.dart';
import 'exercise_repository.dart';
import 'food_repository.dart';
import 'local_write_guard.dart';
import 'meal_template_repository.dart';
import 'saved_food_repository.dart';
import 'settings_repository.dart';
import 'user_repository.dart';
import 'workout_template_repository.dart';
import 'pending_record_store.dart';
import 'postgrest_pages.dart';
import 'sync_step_runner.dart';
import 'weight_repository.dart';

/// Supabase users テーブルの行。
class RemoteUserProfile {
  const RemoteUserProfile({
    required this.id,
    this.email,
    required this.createdAt,
  });

  final String id;
  final String? email;
  final DateTime createdAt;

  factory RemoteUserProfile.fromJson(Map<String, dynamic> json) {
    return RemoteUserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Isar と Supabase の双方向同期。
abstract class DataSyncRepository {
  Future<RemoteUserProfile> ensureUserProfile({
    required String userId,
    String? email,
  });

  Future<RemoteUserProfile?> fetchUserProfile(String userId);

  Future<void> pullRemoteToLocal(
    String userId, {
    Set<String> skipTables = const {},
    LocalWriteGuard? mayWrite,
  });

  Future<void> pullSavedFoodsRemoteToLocal(String userId);

  Future<void> pushLocalToRemote(String userId, {LocalWriteGuard? mayWrite});

  /// 保存した食事1件だけを送る。全表の読み直しは画面を止める。
  Future<void> pushFoodEntry({
    required String userId,
    required FoodEntry entry,
  });

  Future<void> deleteFoodEntry({
    required String userId,
    required String entryId,
  });

  Future<void> deleteAlcoholEntry({
    required String userId,
    required String entryId,
  });

  Future<void> deleteExerciseEntry({
    required String userId,
    required String entryId,
  });

  Future<void> deleteWeightEntry({
    required String userId,
    required String entryId,
  });

  /// Supabase 等のリモート削除が有効か。
  bool get supportsRemoteFoodEntryDelete;

  bool get supportsRemoteAlcoholEntryDelete;

  bool get supportsRemoteExerciseEntryDelete;

  bool get supportsRemoteWeightEntryDelete;
}

/// Supabase 実装。
class SupabaseDataSyncRepository implements DataSyncRepository {
  SupabaseDataSyncRepository({
    required UserRepositoryBase userRepository,
    required SettingsRepositoryBase settingsRepository,
    required FoodRepositoryBase foodRepository,
    required ExerciseRepositoryBase exerciseRepository,
    required AlcoholRepositoryBase alcoholRepository,
    required WeightRepositoryBase weightRepository,
    FoodMasterRepositories? foodMaster,
    HealthRepository? healthWorkouts,
    SupabaseClient? client,
    PendingRecordStore? pendingRecords,
  }) : _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _alcoholRepository = alcoholRepository,
       _weightRepository = weightRepository,
       _foodMaster = foodMaster,
       _healthWorkouts = healthWorkouts,
       _pendingRecords = pendingRecords,
       _client = client ?? Supabase.instance.client;

  final UserRepositoryBase _userRepository;
  final SettingsRepositoryBase _settingsRepository;
  final FoodRepositoryBase _foodRepository;
  final ExerciseRepositoryBase _exerciseRepository;
  final AlcoholRepositoryBase _alcoholRepository;
  final WeightRepositoryBase _weightRepository;
  final FoodMasterRepositories? _foodMaster;
  final HealthRepository? _healthWorkouts;
  final PendingRecordStore? _pendingRecords;
  final SupabaseClient _client;
  Set<String> _skipPull = const {};

  @override
  bool get supportsRemoteFoodEntryDelete => true;

  @override
  bool get supportsRemoteAlcoholEntryDelete => true;

  @override
  bool get supportsRemoteExerciseEntryDelete => true;

  @override
  bool get supportsRemoteWeightEntryDelete => true;

  @override
  Future<RemoteUserProfile> ensureUserProfile({
    required String userId,
    String? email,
  }) async {
    return runSyncStep(
      step: SyncStep.ensureUserProfile,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'users',
      operation: 'select/insert',
      action: () async {
        final existing = await _client
            .from('users')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (existing != null) {
          return RemoteUserProfile.fromJson(existing);
        }

        final created = await _client
            .from('users')
            .insert({'id': userId, 'email': email})
            .select()
            .single();

        return RemoteUserProfile.fromJson(created);
      },
    );
  }

  @override
  Future<RemoteUserProfile?> fetchUserProfile(String userId) async {
    final row = await _client
        .from('users')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return RemoteUserProfile.fromJson(row);
  }

  @override
  Future<void> pullRemoteToLocal(
    String userId, {
    Set<String> skipTables = const {},
    LocalWriteGuard? mayWrite,
  }) async {
    _skipPull = skipTables;
    try {
      await _pullRemoteToLocal(userId, mayWrite);
    } finally {
      _skipPull = const {};
    }
  }

  Future<bool> _allowPull(String table) async {
    if (_skipPull.contains(table)) {
      debugPrint('[AYG] skip pull $table after failed push');
      return false;
    }
    if (await _pendingRecords?.isTableDirty(table) ?? false) {
      debugPrint('[AYG] skip pull $table while local changes are unsent');
      return false;
    }
    return true;
  }

  Future<void> _pullRemoteToLocal(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    if (await _allowPull('profiles')) {
      await runSyncStep(
        step: SyncStep.fetchUserProfile,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'profiles',
        operation: 'select',
        action: () => _pullProfile(userId, mayWrite),
      );
    }
    if (await _allowPull('goals')) {
      await runSyncStep(
        step: SyncStep.fetchGoal,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'goals',
        operation: 'select',
        action: () => _pullGoal(userId, mayWrite),
      );
    }
    if (await _allowPull('nutrition_settings')) {
      await runSyncStep(
        step: SyncStep.fetchNutritionSettings,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'nutrition_settings',
        operation: 'select',
        action: () => _pullNutritionSettings(userId, mayWrite),
      );
    }
    if (await _allowPull('health_snapshots')) {
      await runSyncStep(
        step: SyncStep.fetchHealthSnapshot,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'health_snapshots',
        operation: 'select',
        action: () => _pullHealthSnapshot(userId, mayWrite),
      );
    }
    if (await _allowPull('app_settings')) {
      await runSyncStep(
        step: SyncStep.fetchAppSettings,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'app_settings',
        operation: 'select',
        action: () => _pullAppSettings(userId, mayWrite),
      );
    }
    if (await _allowPull('food_entries')) {
      await runSyncStep(
        step: SyncStep.fetchFoodEntries,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'food_entries',
        operation: 'select',
        action: () => _pullFoodEntries(userId, mayWrite),
      );
    }
    if (await _allowPull('exercise_entries')) {
      await runSyncStep(
        step: SyncStep.fetchExerciseEntries,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'exercise_entries',
        operation: 'select',
        action: () => _pullExerciseEntries(userId, mayWrite),
      );
    }
    if (await _allowPull('alcohol_entries')) {
      await runOptionalSyncStep(
        step: SyncStep.fetchAlcoholEntries,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'alcohol_entries',
        operation: 'select',
        action: () => _pullAlcoholEntries(userId, mayWrite),
      );
    }
    if (await _allowPull('weight_entries')) {
      await runSyncStep(
        step: SyncStep.fetchWeightEntries,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'weight_entries',
        operation: 'select',
        action: () => _pullWeightEntries(userId, mayWrite),
      );
    }
    if (await _allowPull('saved_foods')) {
      await runOptionalSyncStep(
        step: SyncStep.fetchSavedFoods,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'saved_foods',
        operation: 'select',
        action: () => _pullSavedFoods(userId, mayWrite),
      );
    }
    if (await _allowPull('meal_templates')) {
      await runOptionalSyncStep(
        step: SyncStep.fetchMealTemplates,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'meal_templates',
        operation: 'select',
        action: () => _pullMealTemplates(userId, mayWrite),
      );
    }
    if (await _allowPull('workout_templates')) {
      await runOptionalSyncStep(
        step: SyncStep.fetchWorkoutTemplates,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'workout_templates',
        operation: 'select',
        action: () => _pullWorkoutTemplates(userId, mayWrite),
      );
    }
    if (await _allowPull('health_workouts')) {
      await runOptionalSyncStep(
        step: SyncStep.fetchHealthWorkouts,
        repository: 'SupabaseDataSyncRepository',
        tableName: 'health_workouts',
        operation: 'select',
        action: () => _pullHealthWorkouts(userId, mayWrite),
      );
    }
  }

  @override
  Future<void> pullSavedFoodsRemoteToLocal(String userId) async {
    await _pullSavedFoods(userId);
  }

  @override
  Future<void> pushLocalToRemote(
    String userId, {
    LocalWriteGuard? mayWrite,
  }) async {
    await runPushSteps(
      [
        (table: 'profiles', action: () => _pushProfile(userId)),
        (table: 'goals', action: () => _pushGoal(userId)),
        (
          table: 'nutrition_settings',
          action: () => _pushNutritionSettings(userId),
        ),
        (table: 'health_snapshots', action: () => _pushHealthSnapshot(userId)),
        (table: 'app_settings', action: () => _pushAppSettings(userId)),
        (table: 'food_entries', action: () => _pushFoodEntries(userId)),
        (table: 'exercise_entries', action: () => _pushExerciseEntries(userId)),
        (table: 'alcohol_entries', action: () => _pushAlcoholEntries(userId)),
        (table: 'weight_entries', action: () => _pushWeightEntries(userId)),
        (table: 'saved_foods', action: () => _pushSavedFoods(userId)),
        (table: 'meal_templates', action: () => _pushMealTemplates(userId)),
        (
          table: 'workout_templates',
          action: () => _pushWorkoutTemplates(userId),
        ),
        (table: 'health_workouts', action: () => _pushHealthWorkouts(userId)),
      ],
      between: _yieldToUi,
      stillCurrent: mayWrite,
    );
  }

  Future<List<R>> _mapYielding<T, R>(
    List<T> items,
    R Function(T item) map,
  ) async {
    if (items.length < 200) {
      return [for (final item in items) map(item)];
    }
    final rows = <R>[];
    for (var i = 0; i < items.length; i++) {
      rows.add(map(items[i]));
      if ((i + 1) % 200 == 0) {
        await _yieldToUi();
      }
    }
    return rows;
  }

  /// 表と表のあいだにタップを通す。テストではタイマーを待たずに返す。
  Future<void> _yieldToUi() {
    final bindingName = SchedulerBinding.instance.runtimeType.toString();
    if (bindingName.contains('TestWidgetsFlutterBinding')) {
      return Future<void>.value();
    }
    return Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> deleteFoodEntry({
    required String userId,
    required String entryId,
  }) async {
    await runSyncStep(
      step: SyncStep.deleteFoodEntry,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'food_entries',
      operation: 'delete',
      action: () async {
        await _client
            .from('food_entries')
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', entryId)
            .select('entry_id');
        // 0件は、本番にその行が無い。削除済みとして成功にする。
      },
    );
  }

  @override
  Future<void> deleteAlcoholEntry({
    required String userId,
    required String entryId,
  }) async {
    await runSyncStep(
      step: SyncStep.deleteAlcoholEntry,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'alcohol_entries',
      operation: 'delete',
      action: () async {
        await _client
            .from('alcohol_entries')
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', entryId)
            .select('entry_id');
      },
    );
  }

  @override
  Future<void> deleteExerciseEntry({
    required String userId,
    required String entryId,
  }) async {
    await runSyncStep(
      step: SyncStep.deleteExerciseEntry,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'exercise_entries',
      operation: 'delete',
      action: () async {
        await _client
            .from('exercise_entries')
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', entryId)
            .select('entry_id');
      },
    );
  }

  @override
  Future<void> deleteWeightEntry({
    required String userId,
    required String entryId,
  }) async {
    await runSyncStep(
      step: SyncStep.deleteWeightEntry,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'weight_entries',
      operation: 'delete',
      action: () async {
        await _client
            .from('weight_entries')
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', entryId)
            .select('entry_id');
      },
    );
  }

  Future<void> _pullProfile(String userId, LocalWriteGuard? mayWrite) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _savePulledProfile(
      UserProfile(
        birthDate: DateTime.parse(row['birth_date'] as String),
        gender: _parseGender(row['gender'] as String?),
        heightCm: (row['height_cm'] as num).toDouble(),
        weightKg: (row['weight_kg'] as num).toDouble(),
        displayName: _readDisplayName(row['display_name']),
      ),
      mayWrite,
    );
  }

  Future<void> _savePulledProfile(
    UserProfile profile,
    LocalWriteGuard? mayWrite,
  ) {
    final repo = _userRepository;
    if (repo is UserRepository) {
      return repo.saveProfileForSync(profile, mayWrite: mayWrite);
    }
    if (!localWriteAllowed(mayWrite)) {
      return Future<void>.value();
    }
    return repo.saveProfile(profile);
  }

  String _readDisplayName(Object? raw) {
    if (raw is! String) {
      return '';
    }
    return raw.trim();
  }

  Gender _parseGender(String? raw) {
    if (raw == null) {
      throw FormatException('gender is null');
    }
    for (final gender in Gender.values) {
      if (gender.name == raw) {
        return gender;
      }
    }
    throw FormatException('unknown gender: $raw');
  }

  Future<void> _pushProfile(String userId) async {
    final profile = await _userRepository.loadProfile();
    if (profile == null) {
      return;
    }

    final displayName = profile.displayName.trim();
    await _client.from('profiles').upsert({
      'user_id': userId,
      'birth_date': profile.birthDate.toIso8601String(),
      'gender': profile.gender.name,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
      'display_name': displayName.isEmpty ? null : displayName,
    }, onConflict: 'user_id');
    await _pendingRecords?.acknowledgeTable('profiles');
  }

  Future<void> _pullGoal(String userId, LocalWriteGuard? mayWrite) async {
    final row = await _client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _savePulledGoal(
      Goal(
        type: _parseGoalType(row['goal_type'] as String?),
        targetWeightKg: (row['target_weight_kg'] as num).toDouble(),
        targetDate: DateTime.parse(row['target_date'] as String),
        goalPace: row.containsKey('goal_pace')
            ? GoalPace.fromName(row['goal_pace'] as String?)
            : GoalPace.standard,
      ),
      mayWrite,
    );
  }

  Future<void> _savePulledGoal(Goal goal, LocalWriteGuard? mayWrite) {
    final repo = _userRepository;
    if (repo is UserRepository) {
      return repo.saveGoalForSync(goal, mayWrite: mayWrite);
    }
    if (!localWriteAllowed(mayWrite)) {
      return Future<void>.value();
    }
    return repo.saveGoal(goal);
  }

  GoalType _parseGoalType(String? raw) {
    if (raw == null) {
      throw FormatException('goal_type is null');
    }
    for (final type in GoalType.values) {
      if (type.name == raw) {
        return type;
      }
    }
    throw FormatException('unknown goal_type: $raw');
  }

  Future<void> _pushGoal(String userId) async {
    final goal = await _userRepository.loadGoal();
    if (goal == null) {
      return;
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'goal_type': goal.type.name,
      'target_weight_kg': goal.targetWeightKg,
      'target_date': goal.targetDate.toIso8601String(),
      'goal_pace': goal.type == GoalType.maintain ? null : goal.goalPace.name,
    };

    await _client.from('goals').upsert(payload, onConflict: 'user_id');
    await _pendingRecords?.acknowledgeTable('goals');
  }

  Future<void> _pullNutritionSettings(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final row = await _client
        .from('nutrition_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _savePulledNutrition(
      NutritionSettings(
        useHealthIntegration: row['use_health_integration'] as bool,
        activityLevel: row['activity_level'] == null
            ? null
            : _parseActivityLevel(row['activity_level'] as String?),
        calorieTargetMode: CalorieTargetMode.fromName(
          row['calorie_target_mode'] as String?,
        ),
        manualTargetKcal: _optionalDouble(row, 'manual_target_kcal'),
        manualProteinG: _optionalDouble(row, 'manual_protein_g'),
        manualFatG: _optionalDouble(row, 'manual_fat_g'),
        manualCarbG: _optionalDouble(row, 'manual_carb_g'),
        autoFoodTargetKcal: _optionalDouble(row, 'auto_food_target_kcal'),
        autoFoodTargetOn: _optionalDate(row, 'auto_food_target_on'),
        autoFoodTargetPriorKcal: _optionalDouble(
          row,
          'auto_food_target_prior_kcal',
        ),
      ),
      mayWrite,
    );
  }

  Future<void> _savePulledNutrition(
    NutritionSettings settings,
    LocalWriteGuard? mayWrite,
  ) {
    final repo = _settingsRepository;
    if (repo is SettingsRepository) {
      return repo.saveNutritionSettingsForSync(settings, mayWrite: mayWrite);
    }
    if (!localWriteAllowed(mayWrite)) {
      return Future<void>.value();
    }
    return repo.saveNutritionSettings(settings);
  }

  ActivityLevel _parseActivityLevel(String? raw) {
    if (raw == null) {
      throw FormatException('activity_level is null');
    }
    for (final level in ActivityLevel.values) {
      if (level.name == raw) {
        return level;
      }
    }
    throw FormatException('unknown activity_level: $raw');
  }

  Future<void> _pushNutritionSettings(String userId) async {
    final settings = await _settingsRepository.loadNutritionSettings();
    if (settings == null) {
      return;
    }

    await _client.from('nutrition_settings').upsert({
      'user_id': userId,
      'use_health_integration': settings.useHealthIntegration,
      'activity_level': settings.activityLevel?.name,
      'calorie_target_mode': settings.calorieTargetMode.name,
      'manual_target_kcal': settings.manualTargetKcal,
      'manual_protein_g': settings.manualProteinG,
      'manual_fat_g': settings.manualFatG,
      'manual_carb_g': settings.manualCarbG,
      'auto_food_target_kcal': settings.autoFoodTargetKcal,
      'auto_food_target_on': settings.autoFoodTargetOn
          ?.toIso8601String()
          .split('T')
          .first,
      'auto_food_target_prior_kcal': settings.autoFoodTargetPriorKcal,
    }, onConflict: 'user_id');
    await _pendingRecords?.acknowledgeTable('nutrition_settings');
  }

  double? _optionalDouble(Map<String, dynamic> row, String key) {
    if (!row.containsKey(key) || row[key] == null) {
      return null;
    }
    return (row[key] as num).toDouble();
  }

  DateTime? _optionalDate(Map<String, dynamic> row, String key) {
    if (!row.containsKey(key) || row[key] == null) {
      return null;
    }
    return DateTime.parse(row[key] as String);
  }

  Future<void> _pullHealthSnapshot(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final row = await _client
        .from('health_snapshots')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _savePulledHealthSnapshot(
      HealthSnapshot(
        activeEnergyBurnedKcal: (row['active_energy_burned_kcal'] as num?)
            ?.toDouble(),
        weightKg: (row['weight_kg'] as num?)?.toDouble(),
        weightMeasuredAt: _optionalDate(row, 'weight_measured_at'),
      ),
      mayWrite,
    );
  }

  Future<void> _savePulledHealthSnapshot(
    HealthSnapshot snapshot,
    LocalWriteGuard? mayWrite,
  ) {
    final repo = _settingsRepository;
    if (repo is SettingsRepository) {
      return repo.saveHealthSnapshotForSync(snapshot, mayWrite: mayWrite);
    }
    if (!localWriteAllowed(mayWrite)) {
      return Future<void>.value();
    }
    return repo.saveHealthSnapshot(snapshot);
  }

  Future<void> _pushHealthSnapshot(String userId) async {
    final snapshot = await _settingsRepository.loadHealthSnapshot();
    if (snapshot == null) {
      return;
    }

    await _client.from('health_snapshots').upsert({
      'user_id': userId,
      'active_energy_burned_kcal': snapshot.activeEnergyBurnedKcal,
      'weight_kg': snapshot.weightKg,
      'weight_measured_at': snapshot.weightMeasuredAt?.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id');
    await _pendingRecords?.acknowledgeTable('health_snapshots');
  }

  Future<void> _pullAppSettings(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final row = await _client
        .from('app_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    final settings = AppSettings(
      onboardingComplete: row['onboarding_complete'] as bool,
    );
    final repo = _settingsRepository;
    if (repo is SettingsRepository) {
      await repo.saveAppSettingsForSync(settings, mayWrite: mayWrite);
      return;
    }
    if (!localWriteAllowed(mayWrite)) {
      return;
    }
    await repo.saveAppSettings(settings);
  }

  Future<void> _pushAppSettings(String userId) async {
    final settings = await _settingsRepository.loadAppSettings();
    if (!settings.onboardingComplete) {
      // 手元が「未完了」なのは、ログアウトで消した直後か新しい端末で、まだ
      // サーバから取っていないだけ。ここで送ると、取得の前にサーバの「完了」を
      // false で上書きし、同じアカウントで入り直すたびに初回設定（Health・
      // プロフィール）からやり直しになる。未完了に戻す操作は無いので送らない。
      await _pendingRecords?.acknowledgeTable('app_settings');
      return;
    }
    await _client.from('app_settings').upsert({
      'user_id': userId,
      'onboarding_complete': settings.onboardingComplete,
    }, onConflict: 'user_id');
    await _pendingRecords?.acknowledgeTable('app_settings');
  }

  Future<void> _pullFoodEntries(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final rows = await fetchAllUserRows(
      _client,
      table: 'food_entries',
      userId: userId,
      orderBy: const ['logged_at', 'entry_id'],
    );

    final remote = rows.map(FoodMasterRowMapper.foodEntryFromRow).toList();
    await mergeRepositoryEntries(
      loadLocal: _foodRepository.loadAll,
      remote: remote,
      idOf: (FoodEntry entry) => entry.id,
      clearAll: _foodRepository.clearAll,
      saveAll: _foodRepository.saveAll,
      replaceAll: (entries) => _replaceFoods(entries, mayWrite),
      preferLocalIds: await _preferLocal(PendingRecordKind.food),
      pendingDeleteIds: await _pendingDeletes(PendingRecordKind.food),
    );
  }

  @override
  Future<void> pushFoodEntry({
    required String userId,
    required FoodEntry entry,
  }) {
    return _upsertFoodEntries(userId, [entry]);
  }

  Future<void> _pushFoodEntries(String userId) async {
    final entries = await _foodRepository.loadAll();
    await _yieldToUi();
    final pending = await _preferLocal(PendingRecordKind.food);
    if (entries.isEmpty && pending.isNotEmpty) {
      await _pendingRecords?.markTableDirty('food_entries');
      throw StateError('pending food rows are not readable');
    }
    if (entries.isNotEmpty) {
      await _upsertFoodEntries(userId, entries);
    }
    await _sendPendingDeletes(
      userId: userId,
      table: 'food_entries',
      kind: PendingRecordKind.food,
    );
    await _acknowledgeTableIfSent('food_entries', PendingRecordKind.food);
  }

  /// 送信が最後まで通り、未送信の上書きも削除も残っていなければ、表の
  /// 「送信失敗」印を外す。外さないと、一度でも送信に失敗した表は
  /// 二度と取得されず、ホームの「未送信の記録があります」も消えない。
  Future<void> _acknowledgeTableIfSent(
    String table,
    PendingRecordKind kind,
  ) async {
    final store = _pendingRecords;
    if (store == null || !await store.isTableDirty(table)) {
      return;
    }
    if ((await store.preferLocalIds(kind)).isNotEmpty) {
      return;
    }
    if ((await store.pendingDeleteIds(kind)).isNotEmpty) {
      return;
    }
    await store.acknowledgeTable(table);
  }

  Future<void> _upsertFoodEntries(
    String userId,
    List<FoodEntry> entries,
  ) async {
    if (entries.isEmpty) {
      return;
    }

    final rows = await _mapYielding(
      entries,
      (entry) => FoodMasterRowMapper.foodEntryToRow(entry, userId: userId),
    );
    try {
      await upsertDroppingUnknownColumns(
        table: 'food_entries',
        rows: rows,
        requiredColumns: foodEntryRequiredColumns,
        upsert: (current) => _client
            .from('food_entries')
            .upsert(current, onConflict: 'user_id,entry_id'),
      );
    } catch (error) {
      await _keepUnsynced(
        PendingRecordKind.food,
        entries.map((entry) => entry.id),
      );
      await _pendingRecords?.markTableDirty('food_entries');
      rethrow;
    }
    final currentIds = <String>[];
    for (final entry in entries) {
      final current = await _currentFood(entry.id);
      if (current != null && foodEntryPayloadEquals(current, entry)) {
        currentIds.add(entry.id);
      }
    }
    await _pendingRecords?.acknowledgeUpserts(
      PendingRecordKind.food,
      currentIds,
    );
    if (currentIds.length != entries.length) {
      await _pendingRecords?.markTableDirty('food_entries');
    }
  }

  Future<FoodEntry?> _currentFood(String id) async {
    final repo = _foodRepository;
    if (repo is FoodRepository) {
      return repo.findById(id);
    }
    for (final entry in await repo.loadAll()) {
      if (entry.id == id) {
        return entry;
      }
    }
    return null;
  }

  Future<void> _replaceFoods(
    List<FoodEntry> entries,
    LocalWriteGuard? mayWrite,
  ) {
    final repo = _foodRepository;
    if (repo is FoodRepository) {
      return repo.replaceAll(entries, mayWrite: mayWrite);
    }
    return _replaceByClear(repo.clearAll, repo.saveAll, entries, mayWrite);
  }

  Future<void> _replaceExercises(
    List<ExerciseEntry> entries,
    LocalWriteGuard? mayWrite,
  ) {
    final repo = _exerciseRepository;
    if (repo is ExerciseRepository) {
      return repo.replaceAll(entries, mayWrite: mayWrite);
    }
    return _replaceByClear(repo.clearAll, repo.saveAll, entries, mayWrite);
  }

  Future<void> _replaceAlcohol(
    List<AlcoholEntry> entries,
    LocalWriteGuard? mayWrite,
  ) {
    final repo = _alcoholRepository;
    if (repo is AlcoholRepository) {
      return repo.replaceAll(entries, mayWrite: mayWrite);
    }
    return _replaceByClear(repo.clearAll, repo.saveAll, entries, mayWrite);
  }

  Future<void> _replaceWeights(
    List<WeightEntry> entries,
    LocalWriteGuard? mayWrite,
  ) {
    final repo = _weightRepository;
    if (repo is WeightRepository) {
      return repo.replaceAll(entries, mayWrite: mayWrite);
    }
    return _replaceByClear(
      repo.clearAll,
      (merged) async {
        for (final entry in merged) {
          await repo.save(entry);
        }
      },
      entries,
      mayWrite,
    );
  }

  Future<void> _keepUnsynced(
    PendingRecordKind kind,
    Iterable<String> ids,
  ) async {
    final store = _pendingRecords;
    if (store == null) {
      return;
    }
    for (final id in ids) {
      await store.markUpsert(kind, id);
    }
  }

  Future<void> _pullSavedFoods(
    String userId, [
    LocalWriteGuard? mayWrite,
  ]) async {
    final foodMaster = _foodMaster;
    if (foodMaster?.remoteSavedFoods == null) {
      return;
    }
    final remoteFoods = await foodMaster!.savedFoods.pullAllOwnRemote(userId);
    final local = foodMaster.localSavedFoods;
    if (local is IsarSavedFoodRepository) {
      await local.replaceAllOwnLocalIfCurrent(
        userId,
        remoteFoods,
        mayWrite: mayWrite,
      );
      return;
    }
    if (!localWriteAllowed(mayWrite)) {
      return;
    }
    await foodMaster.savedFoods.replaceAllOwnLocal(userId, remoteFoods);
  }

  Future<void> _pushSavedFoods(String userId) async {
    final foodMaster = _foodMaster;
    if (foodMaster?.remoteSavedFoods == null) {
      return;
    }
    try {
      final localFoods = await foodMaster!.localSavedFoods
          .loadAllOwnIncludingDeleted(userId);
      await foodMaster.savedFoods.pushAllOwnRemote(userId, localFoods);
      await _pendingRecords?.acknowledgeTable('saved_foods');
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _pullMealTemplates(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final foodMaster = _foodMaster;
    final remote = foodMaster?.remoteMealTemplates;
    if (remote == null) {
      return;
    }

    final templates = await remote.pullAllOwn(userId);
    final itemsByTemplate = await remote.pullAllItems(userId);
    final local = foodMaster!.mealTemplates;
    if (local is MealTemplateRepository) {
      await local.applyRemoteForSync(
        ownerUserId: userId,
        templates: templates,
        itemsByTemplate: itemsByTemplate,
        mayWrite: mayWrite,
      );
      return;
    }
    if (!localWriteAllowed(mayWrite)) {
      return;
    }

    await local.clearForOwner(userId);
    if (templates.isEmpty) {
      return;
    }

    await local.saveAll(templates);
    for (final template in templates) {
      await local.replaceItems(
        ownerUserId: userId,
        templateId: template.templateId,
        items: itemsByTemplate[template.templateId] ?? const [],
      );
    }
  }

  Future<void> _pushMealTemplates(String userId) async {
    final foodMaster = _foodMaster;
    final remote = foodMaster?.remoteMealTemplates;
    if (remote == null) {
      return;
    }

    try {
      final templates = await foodMaster!.mealTemplates
          .loadAllOwnIncludingDeleted(userId);
      final itemsByTemplate = <String, List<MealTemplateItem>>{};
      for (final template in templates) {
        itemsByTemplate[template.templateId] = await foodMaster.mealTemplates
            .getItems(ownerUserId: userId, templateId: template.templateId);
      }

      await remote.pushAllOwn(
        userId: userId,
        templates: templates,
        itemsByTemplateId: itemsByTemplate,
      );
      await _pendingRecords?.acknowledgeTable('meal_templates');
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _pullWorkoutTemplates(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final foodMaster = _foodMaster;
    final local = foodMaster?.workoutTemplates;
    final remote = foodMaster?.remoteWorkoutTemplates;
    if (local == null || remote == null) {
      return;
    }

    final templates = await remote.pullAllOwn(userId);
    final itemsByTemplate = await remote.pullAllItems(userId);
    if (local is WorkoutTemplateRepository) {
      await local.applyRemoteForSync(
        ownerUserId: userId,
        templates: templates,
        itemsByTemplate: itemsByTemplate,
        mayWrite: mayWrite,
      );
      return;
    }
    if (!localWriteAllowed(mayWrite)) {
      return;
    }

    await local.clearForOwner(userId);
    if (templates.isEmpty) {
      return;
    }

    for (final template in templates) {
      await local.saveWithItems(
        template: template,
        items: itemsByTemplate[template.templateId] ?? const [],
      );
    }
  }

  Future<void> _pushWorkoutTemplates(String userId) async {
    final foodMaster = _foodMaster;
    final local = foodMaster?.workoutTemplates;
    final remote = foodMaster?.remoteWorkoutTemplates;
    if (local == null || remote == null) {
      return;
    }

    try {
      final templates = await local.loadAllOwnIncludingDeleted(userId);
      final itemsByTemplate = <String, List<WorkoutTemplateItem>>{};
      for (final template in templates) {
        itemsByTemplate[template.templateId] = await local.getItems(
          ownerUserId: userId,
          templateId: template.templateId,
        );
      }

      await remote.pushAllOwn(
        userId: userId,
        templates: templates,
        itemsByTemplateId: itemsByTemplate,
      );
      await _pendingRecords?.acknowledgeTable('workout_templates');
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _pullExerciseEntries(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final rows = await fetchAllUserRows(
      _client,
      table: 'exercise_entries',
      userId: userId,
      orderBy: const ['logged_at', 'entry_id'],
    );

    final remote = rows.map(ExerciseEntryRowMapper.fromRow).toList();
    await mergeRepositoryEntries(
      loadLocal: _exerciseRepository.loadAll,
      remote: remote,
      idOf: (ExerciseEntry entry) => entry.id,
      clearAll: _exerciseRepository.clearAll,
      saveAll: _exerciseRepository.saveAll,
      replaceAll: (entries) => _replaceExercises(entries, mayWrite),
      preferLocalIds: await _preferLocal(PendingRecordKind.exercise),
      pendingDeleteIds: await _pendingDeletes(PendingRecordKind.exercise),
    );
  }

  Future<void> _pushExerciseEntries(String userId) async {
    await _pushExerciseEntriesRows(userId);
    await _acknowledgeTableIfSent(
      'exercise_entries',
      PendingRecordKind.exercise,
    );
  }

  Future<void> _pushExerciseEntriesRows(String userId) async {
    final entries = await _exerciseRepository.loadAll();
    if (entries.isEmpty) {
      await _sendPendingDeletes(
        userId: userId,
        table: 'exercise_entries',
        kind: PendingRecordKind.exercise,
      );
      return;
    }

    final rows = entries
        .map((entry) => ExerciseEntryRowMapper.toRow(entry, userId: userId))
        .toList();
    try {
      await upsertDroppingUnknownColumns(
        table: 'exercise_entries',
        rows: rows,
        requiredColumns: exerciseEntryRequiredColumns,
        upsert: (current) => _client
            .from('exercise_entries')
            .upsert(current, onConflict: 'user_id,entry_id'),
      );
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      if (isClientRejection(error)) {
        await _keepUnsynced(
          PendingRecordKind.exercise,
          entries.map((entry) => entry.id),
        );
        await _pendingRecords?.markTableDirty('exercise_entries');
        rethrow;
      }
      await _client
          .from('exercise_entries')
          .upsert(
            entries
                .map(
                  (entry) => {
                    'user_id': userId,
                    'entry_id': entry.id,
                    'name': entry.name,
                    'duration_min': entry.durationMin,
                    'burned_kcal': entry.burnedKcal,
                    'logged_at': wallClockToDb(entry.loggedAt),
                  },
                )
                .toList(),
            onConflict: 'user_id,entry_id',
          );
    }
    await _pendingRecords?.acknowledgeUpserts(
      PendingRecordKind.exercise,
      entries.map((entry) => entry.id),
    );
    await _sendPendingDeletes(
      userId: userId,
      table: 'exercise_entries',
      kind: PendingRecordKind.exercise,
    );
  }

  Future<void> _pullAlcoholEntries(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final rows = await fetchAllUserRows(
      _client,
      table: 'alcohol_entries',
      userId: userId,
      orderBy: const ['consumed_at', 'entry_id'],
    );

    final remote = rows.map(FoodMasterRowMapper.alcoholEntryFromRow).toList();
    await mergeRepositoryEntries(
      loadLocal: _alcoholRepository.loadAll,
      remote: remote,
      idOf: (AlcoholEntry entry) => entry.id,
      clearAll: _alcoholRepository.clearAll,
      saveAll: _alcoholRepository.saveAll,
      replaceAll: (entries) => _replaceAlcohol(entries, mayWrite),
      preferLocalIds: await _preferLocal(PendingRecordKind.alcohol),
      pendingDeleteIds: await _pendingDeletes(PendingRecordKind.alcohol),
    );
  }

  Future<void> _pushAlcoholEntries(String userId) async {
    await _pushAlcoholEntriesRows(userId);
    await _acknowledgeTableIfSent('alcohol_entries', PendingRecordKind.alcohol);
  }

  Future<void> _pushAlcoholEntriesRows(String userId) async {
    final entries = await _alcoholRepository.loadAll();
    if (entries.isEmpty) {
      await _sendPendingDeletes(
        userId: userId,
        table: 'alcohol_entries',
        kind: PendingRecordKind.alcohol,
      );
      return;
    }

    try {
      await _client
          .from('alcohol_entries')
          .upsert(
            entries
                .map(
                  (entry) => FoodMasterRowMapper.alcoholEntryToRow(
                    entry,
                    userId: userId,
                  ),
                )
                .toList(),
            onConflict: 'user_id,entry_id',
          );
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      await _keepUnsynced(
        PendingRecordKind.alcohol,
        entries.map((entry) => entry.id),
      );
      await _pendingRecords?.markTableDirty('alcohol_entries');
      rethrow;
    }
    await _pendingRecords?.acknowledgeUpserts(
      PendingRecordKind.alcohol,
      entries.map((entry) => entry.id),
    );
    await _sendPendingDeletes(
      userId: userId,
      table: 'alcohol_entries',
      kind: PendingRecordKind.alcohol,
    );
  }

  Future<void> _pullWeightEntries(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final rows = await fetchAllUserRows(
      _client,
      table: 'weight_entries',
      userId: userId,
      orderBy: const ['recorded_at', 'entry_id'],
    );

    final entries = rows
        .map(
          (row) => WeightEntry(
            id: row['entry_id'] as String,
            weightKg: (row['weight_kg'] as num).toDouble(),
            recordedAt: wallClockFromDb(row['recorded_at'] as String),
            source: _parseWeightSource(row['source'] as String?),
          ),
        )
        .toList();

    await mergeRepositoryEntries(
      loadLocal: _weightRepository.loadAll,
      remote: entries,
      idOf: (WeightEntry entry) => entry.id,
      clearAll: _weightRepository.clearAll,
      saveAll: (merged) async {
        for (final entry in merged) {
          await _weightRepository.save(entry);
        }
      },
      replaceAll: (entries) => _replaceWeights(entries, mayWrite),
      preferLocalIds: await _preferLocal(PendingRecordKind.weight),
      pendingDeleteIds: await _pendingDeletes(PendingRecordKind.weight),
    );
  }

  WeightSource _parseWeightSource(String? raw) {
    if (raw == null) {
      throw FormatException('weight source is null');
    }
    for (final source in WeightSource.values) {
      if (source.storageValue == raw) {
        return source;
      }
    }
    throw FormatException('unknown weight source: $raw');
  }

  Future<void> _pushWeightEntries(String userId) async {
    await _pushWeightEntriesRows(userId);
    await _acknowledgeTableIfSent('weight_entries', PendingRecordKind.weight);
  }

  Future<void> _pushWeightEntriesRows(String userId) async {
    final entries = await _weightRepository.loadAll();
    if (entries.isEmpty) {
      await _sendPendingDeletes(
        userId: userId,
        table: 'weight_entries',
        kind: PendingRecordKind.weight,
      );
      return;
    }

    try {
      await _client
          .from('weight_entries')
          .upsert(
            entries
                .map(
                  (entry) => {
                    'user_id': userId,
                    'entry_id': entry.id,
                    'weight_kg': entry.weightKg,
                    'recorded_at': wallClockToDb(entry.recordedAt),
                    'source': entry.source.storageValue,
                  },
                )
                .toList(),
            onConflict: 'user_id,entry_id',
          );
    } catch (error) {
      await _keepUnsynced(
        PendingRecordKind.weight,
        entries.map((entry) => entry.id),
      );
      await _pendingRecords?.markTableDirty('weight_entries');
      rethrow;
    }
    await _pendingRecords?.acknowledgeUpserts(
      PendingRecordKind.weight,
      entries.map((entry) => entry.id),
    );
    await _sendPendingDeletes(
      userId: userId,
      table: 'weight_entries',
      kind: PendingRecordKind.weight,
    );
  }

  Future<Set<String>> _preferLocal(PendingRecordKind kind) async {
    return await _pendingRecords?.preferLocalIds(kind) ?? const {};
  }

  Future<Set<String>> _pendingDeletes(PendingRecordKind kind) async {
    return await _pendingRecords?.pendingDeleteIds(kind) ?? const {};
  }

  /// 手元から消したが本番に残っている行を、もう一度消す。
  Future<void> _sendPendingDeletes({
    required String userId,
    required String table,
    required PendingRecordKind kind,
  }) async {
    final store = _pendingRecords;
    if (store == null) {
      return;
    }
    final ids = await store.pendingDeleteIds(kind);
    if (ids.isEmpty) {
      return;
    }
    Object? failure;
    for (final id in ids) {
      try {
        await _client
            .from(table)
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', id)
            .select('entry_id');
        await store.forget(kind, id);
      } catch (error) {
        failure = error;
      }
    }
    if (failure != null) {
      throw failure;
    }
  }

  Future<void> _pullHealthWorkouts(
    String userId,
    LocalWriteGuard? mayWrite,
  ) async {
    final store = _healthWorkouts;
    if (store == null) {
      return;
    }
    final rows = await _client
        .from('health_workouts')
        .select()
        .eq('user_id', userId);
    final existing = await store.loadWorkoutRecords();
    final known = existing.map((record) => record.id).toSet();
    final incoming = <HealthWorkoutRecord>[];
    for (final row in rows) {
      final record = healthWorkoutFromRow(Map<String, dynamic>.from(row));
      if (known.add(record.id)) {
        incoming.add(record);
      }
    }
    if (incoming.isEmpty) {
      return;
    }
    await store.saveWorkoutRecords(incoming, mayWrite: mayWrite);
  }

  Future<void> _pushHealthWorkouts(String userId) async {
    final store = _healthWorkouts;
    if (store == null) {
      return;
    }
    final rows = <Map<String, dynamic>>[];
    for (final record in await store.loadWorkoutRecords()) {
      final row = healthWorkoutRow(userId: userId, record: record);
      if (row != null) {
        rows.add(row);
      }
    }
    if (rows.isEmpty) {
      return;
    }
    try {
      await _client
          .from('health_workouts')
          .upsert(rows, onConflict: 'user_id,workout_id');
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      rethrow;
    }
  }
}

/// 1表が失敗しても、残りの表は送る。全部試したあと、失敗があればまとめて投げる。
Future<void> runPushSteps(
  List<({String table, Future<void> Function() action})> steps, {
  Future<void> Function()? between,
  LocalWriteGuard? stillCurrent,
}) async {
  final failures = <({String table, Object error})>[];
  for (final step in steps) {
    // 世代が変わったあとの表は送らない。送りかけの1回は戻せない。
    if (!localWriteAllowed(stillCurrent)) {
      return;
    }
    try {
      await step.action();
    } catch (error, stackTrace) {
      failures.add((table: step.table, error: error));
      debugPrint('[AYG] push ${step.table} failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (between != null) {
      await between();
    }
  }
  if (failures.isNotEmpty) {
    throw PartialPushException(failures);
  }
}

class PartialPushException implements Exception {
  PartialPushException(this.failures);

  final List<({String table, Object error})> failures;

  @override
  String toString() {
    final tables = failures.map((failure) => failure.table).join(', ');
    return 'PartialPushException($tables)';
  }
}

/// 同じ entry_id は、未送信の印が無ければ本番を残す。
/// 未送信の上書きは手元を残す。未送信の削除で手元に無い行は、本番から戻さない。
List<T> mergeEntriesById<T>({
  required List<T> local,
  required List<T> remote,
  required String Function(T entry) idOf,
  Set<String> preferLocalIds = const {},
  Set<String> pendingDeleteIds = const {},
}) {
  final localById = <String, T>{for (final entry in local) idOf(entry): entry};
  final merged = <T>[];
  final seen = <String>{};
  for (final entry in remote) {
    final id = idOf(entry);
    if (!seen.add(id)) {
      continue;
    }
    final keptLocal = localById[id];
    if (pendingDeleteIds.contains(id) && keptLocal == null) {
      continue;
    }
    if (keptLocal != null &&
        (preferLocalIds.contains(id) || pendingDeleteIds.contains(id))) {
      merged.add(keptLocal);
      continue;
    }
    merged.add(entry);
  }
  for (final entry in local) {
    final id = idOf(entry);
    if (seen.contains(id) || pendingDeleteIds.contains(id)) {
      continue;
    }
    merged.add(entry);
  }
  return merged;
}

Future<void> mergeRepositoryEntries<T>({
  required Future<List<T>> Function() loadLocal,
  required List<T> remote,
  required String Function(T entry) idOf,
  required Future<void> Function() clearAll,
  required Future<void> Function(List<T> entries) saveAll,
  Future<void> Function(List<T> entries)? replaceAll,
  Set<String> preferLocalIds = const {},
  Set<String> pendingDeleteIds = const {},
}) async {
  final local = await loadLocal();
  if (remote.isEmpty) {
    return;
  }
  final merged = mergeEntriesById(
    local: local,
    remote: remote,
    idOf: idOf,
    preferLocalIds: preferLocalIds,
    pendingDeleteIds: pendingDeleteIds,
  );
  if (replaceAll != null) {
    await replaceAll(merged);
    return;
  }
  await clearAll();
  if (merged.isEmpty) {
    return;
  }
  await saveAll(merged);
}

Future<void> _replaceByClear<T>(
  Future<void> Function() clearAll,
  Future<void> Function(List<T> entries) saveAll,
  List<T> entries,
  LocalWriteGuard? mayWrite,
) async {
  if (!localWriteAllowed(mayWrite)) {
    return;
  }
  await clearAll();
  if (entries.isNotEmpty) {
    await saveAll(entries);
  }
}

const foodEntryRequiredColumns = {
  'user_id',
  'entry_id',
  'name',
  'quantity',
  'logged_at',
};

const exerciseEntryRequiredColumns = {
  'user_id',
  'entry_id',
  'name',
  'duration_min',
  'burned_kcal',
  'logged_at',
};

/// PGRST204 / 42703 に書かれた列を外して再送する。必須列は外さない。
Future<void> upsertDroppingUnknownColumns({
  required String table,
  required List<Map<String, dynamic>> rows,
  required Set<String> requiredColumns,
  required Future<void> Function(List<Map<String, dynamic>> rows) upsert,
}) async {
  var current = rows;
  final dropped = <String>{};
  while (true) {
    try {
      await upsert(current);
      return;
    } on PostgrestException catch (error) {
      if (!isMissingColumnError(error)) {
        rethrow;
      }
      final column = unknownColumnName(error);
      final present = current.any((row) => row.containsKey(column));
      if (column == null ||
          requiredColumns.contains(column) ||
          !dropped.add(column) ||
          !present) {
        rethrow;
      }
      debugPrint('[AYG] $table upsert dropped column $column');
      current = [
        for (final row in current)
          Map<String, dynamic>.from(row)..remove(column),
      ];
    }
  }
}

String? unknownColumnName(Object error) {
  if (error is! PostgrestException) {
    return null;
  }
  final text = '${error.message} ${error.details ?? ''} ${error.hint ?? ''}';
  final postgrest = RegExp(
    "Could not find the '([^']+)' column",
    caseSensitive: false,
  ).firstMatch(text);
  if (postgrest != null) {
    return postgrest.group(1);
  }
  final postgres = RegExp(
    'column "([^"]+)"',
    caseSensitive: false,
  ).firstMatch(text);
  if (postgres != null) {
    return postgres.group(1);
  }
  if (text.toLowerCase().contains('source_saved_food_version')) {
    return 'source_saved_food_version';
  }
  return null;
}

bool isMissingColumnError(Object error) {
  if (error is! PostgrestException) {
    return false;
  }
  if (error.code == '42703' || error.code == 'PGRST204') {
    return true;
  }
  if (unknownColumnName(error) != null) {
    return true;
  }
  final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
  return message.contains('source_saved_food_version') &&
      message.contains('column');
}

/// 4xx やスキーマ拒否。成功扱いにして未送信印を外さない。
bool isClientRejection(Object error) {
  if (error is! PostgrestException) {
    return false;
  }
  if (isMissingColumnError(error)) {
    return true;
  }
  final code = error.code ?? '';
  if (code == '401' ||
      code == '404' ||
      code == '429' ||
      code == 'PGRST301' ||
      code == 'PGRST202' ||
      code == 'PGRST205') {
    return false;
  }
  if (code.startsWith('PGRST') ||
      code.startsWith('22') ||
      code.startsWith('23')) {
    return true;
  }
  final http = int.tryParse(code);
  if (http != null && http >= 400 && http < 500) {
    return true;
  }
  return false;
}

bool foodEntryPayloadEquals(FoodEntry left, FoodEntry right) {
  final a = FoodMasterRowMapper.foodEntryToRow(left, userId: '_');
  final b = FoodMasterRowMapper.foodEntryToRow(right, userId: '_');
  if (a.length != b.length) {
    return false;
  }
  for (final key in a.keys) {
    if (a[key] != b[key]) {
      return false;
    }
  }
  return true;
}

/// Supabase 未設定時の no-op 同期。
class NoOpDataSyncRepository implements DataSyncRepository {
  @override
  bool get supportsRemoteFoodEntryDelete => false;

  @override
  bool get supportsRemoteAlcoholEntryDelete => false;

  @override
  bool get supportsRemoteExerciseEntryDelete => false;

  @override
  bool get supportsRemoteWeightEntryDelete => false;

  @override
  Future<RemoteUserProfile> ensureUserProfile({
    required String userId,
    String? email,
  }) async {
    return RemoteUserProfile(
      id: userId,
      email: email,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<RemoteUserProfile?> fetchUserProfile(String userId) async => null;

  @override
  Future<void> pullRemoteToLocal(
    String userId, {
    Set<String> skipTables = const {},
    LocalWriteGuard? mayWrite,
  }) async {}

  @override
  Future<void> pullSavedFoodsRemoteToLocal(String userId) async {}

  @override
  Future<void> pushLocalToRemote(
    String userId, {
    LocalWriteGuard? mayWrite,
  }) async {}

  @override
  Future<void> pushFoodEntry({
    required String userId,
    required FoodEntry entry,
  }) async {}

  @override
  Future<void> deleteFoodEntry({
    required String userId,
    required String entryId,
  }) async {}

  @override
  Future<void> deleteAlcoholEntry({
    required String userId,
    required String entryId,
  }) async {}

  @override
  Future<void> deleteExerciseEntry({
    required String userId,
    required String entryId,
  }) async {}

  @override
  Future<void> deleteWeightEntry({
    required String userId,
    required String entryId,
  }) async {}
}
