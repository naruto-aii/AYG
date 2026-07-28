import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_level.dart';
import '../models/app_settings.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/meal_template.dart';
import '../models/goal.dart';
import '../models/health_profile_data.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import 'contracts/exercise_repository_base.dart';
import 'contracts/food_repository_base.dart';
import 'contracts/meal_template_repository_base.dart';
import 'contracts/settings_repository_base.dart';
import 'contracts/user_repository_base.dart';
import 'contracts/weight_repository_base.dart';
import '../models/sync_failure.dart';
import 'food_master_repositories.dart';
import 'supabase/food_master_row_mapper.dart';
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
}

/// Supabase 実装。
class SupabaseDataSyncRepository implements DataSyncRepository {
  SupabaseDataSyncRepository({
    required UserRepositoryBase userRepository,
    required SettingsRepositoryBase settingsRepository,
    required FoodRepositoryBase foodRepository,
    required ExerciseRepositoryBase exerciseRepository,
    required WeightRepositoryBase weightRepository,
    FoodMasterRepositories? foodMaster,
    SupabaseClient? client,
  }) : _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _weightRepository = weightRepository,
       _foodMaster = foodMaster,
       _client = client ?? Supabase.instance.client;

  final UserRepositoryBase _userRepository;
  final SettingsRepositoryBase _settingsRepository;
  final FoodRepositoryBase _foodRepository;
  final ExerciseRepositoryBase _exerciseRepository;
  final WeightRepositoryBase _weightRepository;
  final FoodMasterRepositories? _foodMaster;
  final SupabaseClient _client;

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
  }

  @override
  Future<void> pullSavedFoodsRemoteToLocal(String userId) async {
    await _pullSavedFoods(userId);
  }

  @override
  Future<void> pushLocalToRemote(String userId) async {
    await _pushProfile(userId);
    await _pushGoal(userId);
    await _pushNutritionSettings(userId);
    await _pushHealthSnapshot(userId);
    await _pushAppSettings(userId);
    await _pushFoodEntries(userId);
    await _pushExerciseEntries(userId);
    await _pushWeightEntries(userId);
    await _pushSavedFoods(userId);
    await _pushMealTemplates(userId);
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
      ),
    );
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

    await _client.from('profiles').upsert({
      'user_id': userId,
      'birth_date': profile.birthDate.toIso8601String(),
      'gender': profile.gender.name,
      'height_cm': profile.heightCm,
      'weight_kg': profile.weightKg,
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

    await _client.from('goals').upsert({
      'user_id': userId,
      'goal_type': goal.type.name,
      'target_weight_kg': goal.targetWeightKg,
      'target_date': goal.targetDate.toIso8601String(),
    }, onConflict: 'user_id');
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
    }, onConflict: 'user_id');
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

  Future<void> _pushFoodEntries(String userId) async {
    final entries = await _foodRepository.loadAll();
    if (entries.isEmpty) {
      return;
    }

    await _client
        .from('food_entries')
        .upsert(
          entries
              .map(
                (entry) =>
                    FoodMasterRowMapper.foodEntryToRow(entry, userId: userId),
              )
              .toList(),
          onConflict: 'user_id,entry_id',
        );
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

    await foodMaster!.mealTemplates.clearAll();
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

  Future<void> _pullExerciseEntries(String userId) async {
    final rows = await _client
        .from('exercise_entries')
        .select()
        .eq('user_id', userId);

    final entries = rows
        .map(
          (row) => ExerciseEntry(
            id: row['entry_id'] as String,
            name: row['name'] as String,
            durationMin: row['duration_min'] as int,
            burnedKcal: (row['burned_kcal'] as num).toDouble(),
            loggedAt: DateTime.parse(row['logged_at'] as String),
          ),
        )
        .toList();

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
}

/// Supabase 未設定時の no-op 同期。
class NoOpDataSyncRepository implements DataSyncRepository {
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
}
