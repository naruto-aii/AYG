import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/activity_level.dart';
import '../models/app_settings.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/goal.dart';
import '../models/health_profile_data.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import 'contracts/exercise_repository_base.dart';
import 'contracts/food_repository_base.dart';
import 'contracts/settings_repository_base.dart';
import 'contracts/user_repository_base.dart';
import 'contracts/weight_repository_base.dart';

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
    SupabaseClient? client,
  }) : _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _weightRepository = weightRepository,
       _client = client ?? Supabase.instance.client;

  final UserRepositoryBase _userRepository;
  final SettingsRepositoryBase _settingsRepository;
  final FoodRepositoryBase _foodRepository;
  final ExerciseRepositoryBase _exerciseRepository;
  final WeightRepositoryBase _weightRepository;
  final SupabaseClient _client;

  @override
  Future<RemoteUserProfile> ensureUserProfile({
    required String userId,
    String? email,
  }) async {
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
    await _pullProfile(userId);
    await _pullGoal(userId);
    await _pullNutritionSettings(userId);
    await _pullHealthSnapshot(userId);
    await _pullAppSettings(userId);
    await _pullFoodEntries(userId);
    await _pullExerciseEntries(userId);
    await _pullWeightEntries(userId);
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
        gender: Gender.values.firstWhere(
          (value) => value.name == row['gender'] as String,
        ),
        heightCm: (row['height_cm'] as num).toDouble(),
        weightKg: (row['weight_kg'] as num).toDouble(),
      ),
    );
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
        type: GoalType.values.firstWhere(
          (value) => value.name == row['goal_type'] as String,
        ),
        targetWeightKg: (row['target_weight_kg'] as num).toDouble(),
        targetDate: DateTime.parse(row['target_date'] as String),
      ),
    );
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
            : ActivityLevel.values.firstWhere(
                (value) => value.name == row['activity_level'] as String,
              ),
      ),
    );
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

    await _foodRepository.clearAll();
    if (rows.isEmpty) {
      return;
    }

    final entries = rows
        .map(
          (row) => FoodEntry(
            id: row['entry_id'] as String,
            name: row['name'] as String,
            kcalPerUnit: (row['kcal_per_unit'] as num?)?.toDouble(),
            proteinPerUnit: (row['protein_per_unit'] as num?)?.toDouble(),
            fatPerUnit: (row['fat_per_unit'] as num?)?.toDouble(),
            carbPerUnit: (row['carb_per_unit'] as num?)?.toDouble(),
            quantity: (row['quantity'] as num).toDouble(),
            loggedAt: DateTime.parse(row['logged_at'] as String),
          ),
        )
        .toList();
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
                (entry) => {
                  'user_id': userId,
                  'entry_id': entry.id,
                  'name': entry.name,
                  'kcal_per_unit': entry.kcalPerUnit,
                  'protein_per_unit': entry.proteinPerUnit,
                  'fat_per_unit': entry.fatPerUnit,
                  'carb_per_unit': entry.carbPerUnit,
                  'quantity': entry.quantity,
                  'logged_at': entry.loggedAt.toIso8601String(),
                },
              )
              .toList(),
          onConflict: 'user_id,entry_id',
        );
  }

  Future<void> _pullExerciseEntries(String userId) async {
    final rows = await _client
        .from('exercise_entries')
        .select()
        .eq('user_id', userId);

    await _exerciseRepository.clearAll();
    if (rows.isEmpty) {
      return;
    }

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

    await _weightRepository.clearAll();
    if (rows.isEmpty) {
      return;
    }

    for (final row in rows) {
      await _weightRepository.save(
        WeightEntry(
          id: row['entry_id'] as String,
          weightKg: (row['weight_kg'] as num).toDouble(),
          recordedAt: DateTime.parse(row['recorded_at'] as String),
          source: WeightSource.values.firstWhere(
            (value) => value.storageValue == row['source'] as String,
          ),
        ),
      );
    }
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
  Future<void> pushLocalToRemote(String userId) async {}
}
