import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/activity_level.dart';
import '../models/alcohol_entry.dart';
import '../models/app_settings.dart';
import '../models/calculation/calorie_target_mode.dart';
import '../models/calculation/goal_pace.dart';
import '../models/exercise_entry.dart';
import '../models/food_entry.dart';
import '../models/goal.dart';
import '../models/health_profile_data.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../repositories/pending_record_store.dart';
import '../repositories/supabase/exercise_entry_row_mapper.dart';
import '../repositories/supabase/food_master_row_mapper.dart';

/// 端末に一つしかない食事・運動・飲酒・体重・プロフィールの枠を、
/// 持ち主の user_id ごとにしまう。
///
/// この枠の行には user_id が無い。送る直前に今のセッションの id を付けると、
/// `food_entries` の RLS（auth.uid() = user_id）で拒否されるか、
/// 今のユーザーの行として書き込まれる。持ち主のセッションでだけ戻して送る。
class OwnedLocalRecords {
  const OwnedLocalRecords({
    this.foods = const [],
    this.exercises = const [],
    this.alcohols = const [],
    this.weights = const [],
    this.profile,
    this.goal,
    this.nutrition,
    this.health,
    this.appSettings,
    this.pending = const PendingRecordSnapshot(),
  });

  final List<FoodEntry> foods;
  final List<ExerciseEntry> exercises;
  final List<AlcoholEntry> alcohols;
  final List<WeightEntry> weights;
  final UserProfile? profile;
  final Goal? goal;
  final NutritionSettings? nutrition;
  final HealthSnapshot? health;
  final AppSettings? appSettings;
  final PendingRecordSnapshot pending;

  bool get hasHealthData => _healthHasData(health);

  bool get hasRecords {
    return foods.isNotEmpty ||
        exercises.isNotEmpty ||
        alcohols.isNotEmpty ||
        weights.isNotEmpty ||
        !pending.isEmpty ||
        profile != null ||
        goal != null ||
        nutrition != null ||
        _healthHasData(health) ||
        appSettings?.onboardingComplete == true;
  }

  OwnedLocalRecords copy() {
    return OwnedLocalRecords(
      foods: List<FoodEntry>.of(foods),
      exercises: List<ExerciseEntry>.of(exercises),
      alcohols: List<AlcoholEntry>.of(alcohols),
      weights: List<WeightEntry>.of(weights),
      profile: profile,
      goal: goal,
      nutrition: nutrition,
      health: health,
      appSettings: appSettings,
      pending: pending.copy(),
    );
  }
}

bool _healthHasData(HealthSnapshot? snapshot) {
  if (snapshot == null) {
    return false;
  }
  return snapshot.activeEnergyBurnedKcal != null ||
      snapshot.weightKg != null ||
      snapshot.weightMeasuredAt != null;
}

/// 持ち主ごとの未送信。空の写しで、既にある記録を消さない。
class OwnedLocalRecordShelf {
  OwnedLocalRecordShelf({SharedPreferences? preferences})
    : _preferences = preferences;

  static const storageKey = 'owned_local_records_v1';
  static const activeOwnerKey = 'active_local_owner_user_id';

  final SharedPreferences? _preferences;
  final Map<String, OwnedLocalRecords> _byOwner = {};
  String? _activeOwner;
  bool _loaded = false;
  bool _canPersist = true;

  Future<void> _ensure() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    _activeOwner = preferences.getString(activeOwnerKey)?.toLowerCase();
    final raw = preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      _readBlob(raw);
    } catch (error, stackTrace) {
      _canPersist = false;
      debugPrint('[AYG] owned local records unreadable: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// 今、端末の枠に入っている記録の持ち主。未設定なら null。
  Future<String?> activeOwner() async {
    await _ensure();
    return _activeOwner;
  }

  Future<void> setActiveOwner(String? userId) async {
    await _ensure();
    final next = userId?.toLowerCase();
    _activeOwner = next == null || next.isEmpty ? null : next;
    await _persistActiveOwner();
  }

  /// 空の写しでは、既にある記録を消さない。
  /// 枠を空にしたあとに同じ持ち主でもう一度しまうと、棚が消えるのを防ぐ。
  Future<void> put(String userId, OwnedLocalRecords records) async {
    await _ensure();
    if (!records.hasRecords) {
      return;
    }
    _byOwner[userId.toLowerCase()] = records.copy();
    await _persist();
  }

  Future<OwnedLocalRecords?> peek(String userId) async {
    await _ensure();
    return _byOwner[userId.toLowerCase()];
  }

  /// この持ち主の棚だけ消す。別の持ち主は残す。
  Future<void> drop(String userId) async {
    await _ensure();
    if (_byOwner.remove(userId.toLowerCase()) == null) {
      return;
    }
    await _persist();
  }

  Future<void> _persistActiveOwner() async {
    final preferences = _preferences;
    if (preferences == null || !_canPersist) {
      return;
    }
    try {
      final owner = _activeOwner;
      if (owner == null) {
        await preferences.remove(activeOwnerKey);
        return;
      }
      await preferences.setString(activeOwnerKey, owner);
    } catch (error, stackTrace) {
      debugPrint('[AYG] active local owner was not saved: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null || !_canPersist) {
      return;
    }
    try {
      final owners = <String, Object?>{};
      for (final entry in _byOwner.entries) {
        if (!entry.value.hasRecords) {
          continue;
        }
        owners[entry.key] = _encode(entry.key, entry.value);
      }
      if (owners.isEmpty) {
        await preferences.remove(storageKey);
        return;
      }
      await preferences.setString(storageKey, jsonEncode({'owners': owners}));
    } catch (error, stackTrace) {
      debugPrint('[AYG] owned local records were not saved: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  void _readBlob(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return;
    }
    final owners = decoded['owners'];
    if (owners is! Map) {
      return;
    }
    for (final entry in owners.entries) {
      if (entry.value is! Map) {
        continue;
      }
      final records = _decode(Map<Object?, Object?>.from(entry.value as Map));
      if (records.hasRecords) {
        _byOwner['${entry.key}'.toLowerCase()] = records;
      }
    }
  }
}

Map<String, Object?> _encode(String userId, OwnedLocalRecords records) {
  return {
    'foods': [
      for (final entry in records.foods)
        FoodMasterRowMapper.foodEntryToRow(entry, userId: userId),
    ],
    'exercises': [
      for (final entry in records.exercises)
        ExerciseEntryRowMapper.toRow(entry, userId: userId),
    ],
    'alcohols': [
      for (final entry in records.alcohols)
        FoodMasterRowMapper.alcoholEntryToRow(entry, userId: userId),
    ],
    'weights': [
      for (final entry in records.weights)
        {
          'entry_id': entry.id,
          'weight_kg': entry.weightKg,
          'recorded_at': entry.recordedAt.toIso8601String(),
          'source': entry.source.storageValue,
        },
    ],
    'profile': records.profile == null
        ? null
        : {
            'birthDate': records.profile!.birthDate.toIso8601String(),
            'gender': records.profile!.gender.name,
            'heightCm': records.profile!.heightCm,
            'weightKg': records.profile!.weightKg,
            'displayName': records.profile!.displayName,
          },
    'goal': records.goal == null
        ? null
        : {
            'type': records.goal!.type.name,
            'targetWeightKg': records.goal!.targetWeightKg,
            'targetDate': records.goal!.targetDate.toIso8601String(),
            'goalPace': records.goal!.goalPace.name,
          },
    'nutrition': records.nutrition == null
        ? null
        : {
            'useHealthIntegration': records.nutrition!.useHealthIntegration,
            'activityLevel': records.nutrition!.activityLevel?.name,
            'calorieTargetMode': records.nutrition!.calorieTargetMode.name,
            'manualTargetKcal': records.nutrition!.manualTargetKcal,
            'manualProteinG': records.nutrition!.manualProteinG,
            'manualFatG': records.nutrition!.manualFatG,
            'manualCarbG': records.nutrition!.manualCarbG,
            'autoFoodTargetKcal': records.nutrition!.autoFoodTargetKcal,
            'autoFoodTargetOn': records.nutrition!.autoFoodTargetOn
                ?.toIso8601String(),
            'autoFoodTargetPriorKcal':
                records.nutrition!.autoFoodTargetPriorKcal,
          },
    'health': !_healthHasData(records.health)
        ? null
        : {
            'activeEnergyBurnedKcal': records.health!.activeEnergyBurnedKcal,
            'weightKg': records.health!.weightKg,
            'weightMeasuredAt': records.health!.weightMeasuredAt
                ?.toIso8601String(),
          },
    'appSettings': records.appSettings?.onboardingComplete == true
        ? {'onboardingComplete': true}
        : null,
    'pending': {
      'upserts': records.pending.upserts,
      'deletes': records.pending.deletes,
      'tables': records.pending.tables,
    },
  };
}

OwnedLocalRecords _decode(Map<Object?, Object?> json) {
  return OwnedLocalRecords(
    foods: [
      for (final row in _rows(json['foods']))
        FoodMasterRowMapper.foodEntryFromRow(row),
    ],
    exercises: [
      for (final row in _rows(json['exercises']))
        ExerciseEntryRowMapper.fromRow(row),
    ],
    alcohols: [
      for (final row in _rows(json['alcohols']))
        FoodMasterRowMapper.alcoholEntryFromRow(row),
    ],
    weights: [
      for (final row in _rows(json['weights']))
        WeightEntry(
          id: row['entry_id'] as String,
          weightKg: (row['weight_kg'] as num).toDouble(),
          recordedAt: DateTime.parse(row['recorded_at'] as String),
          source: WeightSource.fromStorage('${row['source']}'),
        ),
    ],
    profile: _profile(json['profile']),
    goal: _goal(json['goal']),
    nutrition: _nutrition(json['nutrition']),
    health: _health(json['health']),
    appSettings: _appSettings(json['appSettings']),
    pending: _pending(json['pending']),
  );
}

List<Map<String, dynamic>> _rows(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is Map) item.map((key, value) => MapEntry('$key', value)),
  ];
}

Map<String, dynamic>? _object(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  return raw.map((key, value) => MapEntry('$key', value));
}

UserProfile? _profile(Object? raw) {
  final json = _object(raw);
  if (json == null) {
    return null;
  }
  return UserProfile(
    birthDate: DateTime.parse(json['birthDate'] as String),
    gender: Gender.values.byName(json['gender'] as String),
    heightCm: (json['heightCm'] as num).toDouble(),
    weightKg: (json['weightKg'] as num).toDouble(),
    displayName: json['displayName'] as String? ?? '',
  );
}

Goal? _goal(Object? raw) {
  final json = _object(raw);
  if (json == null) {
    return null;
  }
  return Goal(
    type: GoalType.values.byName(json['type'] as String),
    targetWeightKg: (json['targetWeightKg'] as num).toDouble(),
    targetDate: DateTime.parse(json['targetDate'] as String),
    goalPace: GoalPace.fromName(json['goalPace'] as String?),
  );
}

NutritionSettings? _nutrition(Object? raw) {
  final json = _object(raw);
  if (json == null) {
    return null;
  }
  final useHealth = json['useHealthIntegration'] == true;
  final levelName = json['activityLevel'] as String?;
  ActivityLevel? level;
  if (levelName != null) {
    for (final candidate in ActivityLevel.values) {
      if (candidate.name == levelName) {
        level = candidate;
      }
    }
  }
  if (!useHealth && level == null) {
    return null;
  }
  return NutritionSettings(
    useHealthIntegration: useHealth,
    activityLevel: level,
    calorieTargetMode: CalorieTargetMode.fromName(
      json['calorieTargetMode'] as String?,
    ),
    manualTargetKcal: (json['manualTargetKcal'] as num?)?.toDouble(),
    manualProteinG: (json['manualProteinG'] as num?)?.toDouble(),
    manualFatG: (json['manualFatG'] as num?)?.toDouble(),
    manualCarbG: (json['manualCarbG'] as num?)?.toDouble(),
    autoFoodTargetKcal: (json['autoFoodTargetKcal'] as num?)?.toDouble(),
    autoFoodTargetOn: json['autoFoodTargetOn'] == null
        ? null
        : DateTime.parse(json['autoFoodTargetOn'] as String),
    autoFoodTargetPriorKcal: (json['autoFoodTargetPriorKcal'] as num?)
        ?.toDouble(),
  );
}

HealthSnapshot? _health(Object? raw) {
  final json = _object(raw);
  if (json == null) {
    return null;
  }
  final snapshot = HealthSnapshot(
    activeEnergyBurnedKcal: (json['activeEnergyBurnedKcal'] as num?)
        ?.toDouble(),
    weightKg: (json['weightKg'] as num?)?.toDouble(),
    weightMeasuredAt: json['weightMeasuredAt'] == null
        ? null
        : DateTime.parse(json['weightMeasuredAt'] as String),
  );
  return _healthHasData(snapshot) ? snapshot : null;
}

AppSettings? _appSettings(Object? raw) {
  final json = _object(raw);
  if (json == null || json['onboardingComplete'] != true) {
    return null;
  }
  return const AppSettings(onboardingComplete: true);
}

PendingRecordSnapshot _pending(Object? raw) {
  final json = _object(raw);
  if (json == null) {
    return const PendingRecordSnapshot();
  }
  return PendingRecordSnapshot(
    upserts: _strings(json['upserts']),
    deletes: _strings(json['deletes']),
    tables: _strings(json['tables']),
  );
}

List<String> _strings(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  return [
    for (final item in raw)
      if (item is String) item,
  ];
}
