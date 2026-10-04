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
import 'food_master_repositories.dart';
import 'health_repository.dart';
import 'supabase/exercise_entry_row_mapper.dart';
import 'supabase/food_master_row_mapper.dart';
import 'supabase/supabase_workout_template_repository.dart';
import 'sync_step_runner.dart';

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

  Future<void> pullRemoteToLocal(String userId);

  Future<void> pullSavedFoodsRemoteToLocal(String userId);

  Future<void> pushLocalToRemote(String userId);

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
  }) : _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _alcoholRepository = alcoholRepository,
       _weightRepository = weightRepository,
       _foodMaster = foodMaster,
       _healthWorkouts = healthWorkouts,
       _client = client ?? Supabase.instance.client;

  final UserRepositoryBase _userRepository;
  final SettingsRepositoryBase _settingsRepository;
  final FoodRepositoryBase _foodRepository;
  final ExerciseRepositoryBase _exerciseRepository;
  final AlcoholRepositoryBase _alcoholRepository;
  final WeightRepositoryBase _weightRepository;
  final FoodMasterRepositories? _foodMaster;
  final HealthRepository? _healthWorkouts;
  final SupabaseClient _client;

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
  Future<void> pullRemoteToLocal(String userId) async {
    await runSyncStep(
      step: SyncStep.fetchUserProfile,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'profiles',
      operation: 'select',
      action: () => _pullProfile(userId),
    );
    await runSyncStep(
      step: SyncStep.fetchGoal,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'goals',
      operation: 'select',
      action: () => _pullGoal(userId),
    );
    await runSyncStep(
      step: SyncStep.fetchNutritionSettings,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'nutrition_settings',
      operation: 'select',
      action: () => _pullNutritionSettings(userId),
    );
    await runSyncStep(
      step: SyncStep.fetchHealthSnapshot,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'health_snapshots',
      operation: 'select',
      action: () => _pullHealthSnapshot(userId),
    );
    await runSyncStep(
      step: SyncStep.fetchAppSettings,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'app_settings',
      operation: 'select',
      action: () => _pullAppSettings(userId),
    );
    await runSyncStep(
      step: SyncStep.fetchFoodEntries,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'food_entries',
      operation: 'select',
      action: () => _pullFoodEntries(userId),
    );
    await runSyncStep(
      step: SyncStep.fetchExerciseEntries,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'exercise_entries',
      operation: 'select',
      action: () => _pullExerciseEntries(userId),
    );
    await runOptionalSyncStep(
      step: SyncStep.fetchAlcoholEntries,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'alcohol_entries',
      operation: 'select',
      action: () => _pullAlcoholEntries(userId),
    );
    await runSyncStep(
      step: SyncStep.fetchWeightEntries,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'weight_entries',
      operation: 'select',
      action: () => _pullWeightEntries(userId),
    );
    await runOptionalSyncStep(
      step: SyncStep.fetchSavedFoods,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'saved_foods',
      operation: 'select',
      action: () => _pullSavedFoods(userId),
    );
    await runOptionalSyncStep(
      step: SyncStep.fetchMealTemplates,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'meal_templates',
      operation: 'select',
      action: () => _pullMealTemplates(userId),
    );
    await runOptionalSyncStep(
      step: SyncStep.fetchWorkoutTemplates,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'workout_templates',
      operation: 'select',
      action: () => _pullWorkoutTemplates(userId),
    );
    await runOptionalSyncStep(
      step: SyncStep.fetchHealthWorkouts,
      repository: 'SupabaseDataSyncRepository',
      tableName: 'health_workouts',
      operation: 'select',
      action: () => _pullHealthWorkouts(userId),
    );
  }

  @override
  Future<void> pullSavedFoodsRemoteToLocal(String userId) async {
    await _pullSavedFoods(userId);
  }

  @override
  Future<void> pushLocalToRemote(String userId) async {
    await _pushProfile(userId);
    await _yieldToUi();
    await _pushGoal(userId);
    await _yieldToUi();
    await _pushNutritionSettings(userId);
    await _yieldToUi();
    await _pushHealthSnapshot(userId);
    await _yieldToUi();
    await _pushAppSettings(userId);
    await _yieldToUi();
    await _pushFoodEntries(userId);
    await _yieldToUi();
    await _pushExerciseEntries(userId);
    await _yieldToUi();
    await _pushAlcoholEntries(userId);
    await _yieldToUi();
    await _pushWeightEntries(userId);
    await _yieldToUi();
    await _pushSavedFoods(userId);
    await _yieldToUi();
    await _pushMealTemplates(userId);
    await _yieldToUi();
    await _pushWorkoutTemplates(userId);
    await _yieldToUi();
    await _pushHealthWorkouts(userId);
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
        final deleted = await _client
            .from('food_entries')
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', entryId)
            .select('entry_id');
        if (deleted.isEmpty) {
          throw StateError(
            'Food entry delete affected 0 rows (entry_id=$entryId)',
          );
        }
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
        final deleted = await _client
            .from('alcohol_entries')
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', entryId)
            .select('entry_id');
        if (deleted.isEmpty) {
          throw StateError(
            'Alcohol entry delete affected 0 rows (entry_id=$entryId)',
          );
        }
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
        final deleted = await _client
            .from('exercise_entries')
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', entryId)
            .select('entry_id');
        if (deleted.isEmpty) {
          throw StateError(
            'Exercise entry delete affected 0 rows (entry_id=$entryId)',
          );
        }
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
        final deleted = await _client
            .from('weight_entries')
            .delete()
            .eq('user_id', userId)
            .eq('entry_id', entryId)
            .select('entry_id');
        if (deleted.isEmpty) {
          throw StateError(
            'Weight entry delete affected 0 rows (entry_id=$entryId)',
          );
        }
      },
    );
  }

  Future<void> _pullProfile(String userId) async {
    final row = await _client
        .from('profiles')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _userRepository.saveProfile(
      UserProfile(
        birthDate: DateTime.parse(row['birth_date'] as String),
        gender: _parseGender(row['gender'] as String?),
        heightCm: (row['height_cm'] as num).toDouble(),
        weightKg: (row['weight_kg'] as num).toDouble(),
        displayName: _readDisplayName(row['display_name']),
      ),
    );
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
  }

  Future<void> _pullGoal(String userId) async {
    final row = await _client
        .from('goals')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _userRepository.saveGoal(
      Goal(
        type: _parseGoalType(row['goal_type'] as String?),
        targetWeightKg: (row['target_weight_kg'] as num).toDouble(),
        targetDate: DateTime.parse(row['target_date'] as String),
        goalPace: row.containsKey('goal_pace')
            ? GoalPace.fromName(row['goal_pace'] as String?)
            : GoalPace.standard,
      ),
    );
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
  }

  Future<void> _pullNutritionSettings(String userId) async {
    final row = await _client
        .from('nutrition_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _settingsRepository.saveNutritionSettings(
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
    );
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

  Future<void> _pullHealthSnapshot(String userId) async {
    final row = await _client
        .from('health_snapshots')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _settingsRepository.saveHealthSnapshot(
      HealthSnapshot(
        activeEnergyBurnedKcal: (row['active_energy_burned_kcal'] as num?)
            ?.toDouble(),
        weightKg: (row['weight_kg'] as num?)?.toDouble(),
        weightMeasuredAt: _optionalDate(row, 'weight_measured_at'),
      ),
    );
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
  }

  Future<void> _pullAppSettings(String userId) async {
    final row = await _client
        .from('app_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (row == null) {
      return;
    }

    await _settingsRepository.saveAppSettings(
      AppSettings(onboardingComplete: row['onboarding_complete'] as bool),
    );
  }

  Future<void> _pushAppSettings(String userId) async {
    final settings = await _settingsRepository.loadAppSettings();
    await _client.from('app_settings').upsert({
      'user_id': userId,
      'onboarding_complete': settings.onboardingComplete,
    }, onConflict: 'user_id');
  }

  Future<void> _pullFoodEntries(String userId) async {
    final rows = await _client
        .from('food_entries')
        .select()
        .eq('user_id', userId);

    final entries = rows.map(FoodMasterRowMapper.foodEntryFromRow).toList();
    await _foodRepository.clearAll();
    if (entries.isEmpty) {
      return;
    }
    await _foodRepository.saveAll(entries);
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
    await _upsertFoodEntries(userId, entries);
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
      await _client
          .from('food_entries')
          .upsert(rows, onConflict: 'user_id,entry_id');
    } on PostgrestException catch (error) {
      if (!isMissingColumnError(error)) {
        rethrow;
      }
      final fallback = [
        for (final row in rows)
          Map<String, dynamic>.from(row)..remove('source_saved_food_version'),
      ];
      await _client
          .from('food_entries')
          .upsert(fallback, onConflict: 'user_id,entry_id');
    }
  }

  Future<void> _pullSavedFoods(String userId) async {
    final foodMaster = _foodMaster;
    if (foodMaster?.remoteSavedFoods == null) {
      return;
    }
    final remoteFoods = await foodMaster!.savedFoods.pullAllOwnRemote(userId);
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
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _pullMealTemplates(String userId) async {
    final foodMaster = _foodMaster;
    final remote = foodMaster?.remoteMealTemplates;
    if (remote == null) {
      return;
    }

    final templates = await remote.pullAllOwn(userId);
    final itemsByTemplate = await remote.pullAllItems(userId);

    await foodMaster!.mealTemplates.clearForOwner(userId);
    if (templates.isEmpty) {
      return;
    }

    await foodMaster.mealTemplates.saveAll(templates);
    for (final template in templates) {
      await foodMaster.mealTemplates.replaceItems(
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
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _pullWorkoutTemplates(String userId) async {
    final foodMaster = _foodMaster;
    final local = foodMaster?.workoutTemplates;
    final remote = foodMaster?.remoteWorkoutTemplates;
    if (local == null || remote == null) {
      return;
    }

    final templates = await remote.pullAllOwn(userId);
    final itemsByTemplate = await remote.pullAllItems(userId);

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
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
      }
      rethrow;
    }
  }

  Future<void> _pullExerciseEntries(String userId) async {
    final rows = await _client
        .from('exercise_entries')
        .select()
        .eq('user_id', userId);

    final entries = rows.map(ExerciseEntryRowMapper.fromRow).toList();

    await _exerciseRepository.clearAll();
    if (entries.isEmpty) {
      return;
    }
    await _exerciseRepository.saveAll(entries);
  }

  Future<void> _pushExerciseEntries(String userId) async {
    final entries = await _exerciseRepository.loadAll();
    if (entries.isEmpty) {
      return;
    }

    try {
      await _client
          .from('exercise_entries')
          .upsert(
            entries
                .map(
                  (entry) =>
                      ExerciseEntryRowMapper.toRow(entry, userId: userId),
                )
                .toList(),
            onConflict: 'user_id,entry_id',
          );
    } catch (error) {
      if (isOptionalTableMissingError(error)) {
        return;
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
                    'logged_at': entry.loggedAt.toIso8601String(),
                  },
                )
                .toList(),
            onConflict: 'user_id,entry_id',
          );
    }
  }

  Future<void> _pullAlcoholEntries(String userId) async {
    final rows = await _client
        .from('alcohol_entries')
        .select()
        .eq('user_id', userId);

    final entries = rows.map(FoodMasterRowMapper.alcoholEntryFromRow).toList();

    await _alcoholRepository.clearAll();
    if (entries.isEmpty) {
      return;
    }
    await _alcoholRepository.saveAll(entries);
  }

  Future<void> _pushAlcoholEntries(String userId) async {
    final entries = await _alcoholRepository.loadAll();
    if (entries.isEmpty) {
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
      rethrow;
    }
  }

  Future<void> _pullWeightEntries(String userId) async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('user_id', userId);

    final entries = rows
        .map(
          (row) => WeightEntry(
            id: row['entry_id'] as String,
            weightKg: (row['weight_kg'] as num).toDouble(),
            recordedAt: DateTime.parse(row['recorded_at'] as String),
            source: _parseWeightSource(row['source'] as String?),
          ),
        )
        .toList();

    await _weightRepository.clearAll();
    if (entries.isEmpty) {
      return;
    }

    for (final entry in entries) {
      await _weightRepository.save(entry);
    }
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
    final entries = await _weightRepository.loadAll();
    if (entries.isEmpty) {
      return;
    }

    await _client
        .from('weight_entries')
        .upsert(
          entries
              .map(
                (entry) => {
                  'user_id': userId,
                  'entry_id': entry.id,
                  'weight_kg': entry.weightKg,
                  'recorded_at': entry.recordedAt.toIso8601String(),
                  'source': entry.source.storageValue,
                },
              )
              .toList(),
          onConflict: 'user_id,entry_id',
        );
  }

  Future<void> _pullHealthWorkouts(String userId) async {
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
    await store.saveWorkoutRecords(incoming);
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

bool isMissingColumnError(Object error) {
  if (error is! PostgrestException) {
    return false;
  }
  if (error.code == '42703' || error.code == 'PGRST204') {
    return true;
  }
  final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
  return message.contains('source_saved_food_version') &&
      message.contains('column');
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
  Future<void> pullRemoteToLocal(String userId) async {}

  @override
  Future<void> pullSavedFoodsRemoteToLocal(String userId) async {}

  @override
  Future<void> pushLocalToRemote(String userId) async {}

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
