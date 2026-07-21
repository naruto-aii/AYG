import '../models/user_profile.dart';

/// Health から取得したプロフィール・当日データ。
class HealthProfileData {
  const HealthProfileData({
    this.birthDate,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.activeEnergyBurnedKcal,
    this.workouts = const [],
  });

  final DateTime? birthDate;
  final Gender? gender;
  final double? heightCm;
  final double? weightKg;
  final double? activeEnergyBurnedKcal;
  final List<HealthWorkoutRecord> workouts;

  static const empty = HealthProfileData();

  HealthProfileData copyWith({
    DateTime? birthDate,
    Gender? gender,
    double? heightCm,
    double? weightKg,
    double? activeEnergyBurnedKcal,
    List<HealthWorkoutRecord>? workouts,
  }) {
    return HealthProfileData(
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      activeEnergyBurnedKcal:
          activeEnergyBurnedKcal ?? this.activeEnergyBurnedKcal,
      workouts: workouts ?? this.workouts,
    );
  }
}

/// Health から取得した Workout（Repository 保存用）。
class HealthWorkoutRecord {
  const HealthWorkoutRecord({
    required this.id,
    required this.activityType,
    required this.startTime,
    required this.endTime,
    this.caloriesBurned,
  });

  final String id;
  final String activityType;
  final DateTime startTime;
  final DateTime endTime;
  final double? caloriesBurned;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'activityType': activityType,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'caloriesBurned': caloriesBurned,
    };
  }

  factory HealthWorkoutRecord.fromJson(Map<String, dynamic> json) {
    return HealthWorkoutRecord(
      id: json['id'] as String,
      activityType: json['activityType'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble(),
    );
  }
}

enum WeightSource {
  health('health'),
  manual('manual');

  const WeightSource(this.storageValue);
  final String storageValue;

  static WeightSource fromStorage(String value) {
    return WeightSource.values.firstWhere(
      (source) => source.storageValue == value,
      orElse: () => WeightSource.manual,
    );
  }
}

/// ローカル保存する体重記録。
class WeightRecord {
  const WeightRecord({
    required this.weightKg,
    required this.recordedAt,
    required this.source,
  });

  final double weightKg;
  final DateTime recordedAt;
  final WeightSource source;

  Map<String, dynamic> toJson() {
    return {
      'weightKg': weightKg,
      'recordedAt': recordedAt.toIso8601String(),
      'source': source.storageValue,
    };
  }

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      weightKg: (json['weightKg'] as num).toDouble(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      source: WeightSource.fromStorage(json['source'] as String),
    );
  }
}
