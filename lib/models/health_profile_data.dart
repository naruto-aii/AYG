import '../models/user_profile.dart';

/// 読み取り対象の型名。解析イベントの type にも使う。
abstract final class HealthReadType {
  static const birthDate = 'BIRTH_DATE';
  static const gender = 'GENDER';
  static const height = 'HEIGHT';
  static const weight = 'WEIGHT';
  static const activeEnergy = 'ACTIVE_ENERGY_BURNED';
  static const workout = 'WORKOUT';
}

/// 1 型の読み取り失敗。値やメッセージは持たない。
class HealthReadFailure {
  const HealthReadFailure({required this.type, required this.code});

  final String type;
  final String code;

  Map<String, String> toProps() => {'type': type, 'code': code};
}

/// Health から取得したプロフィール・当日データ。
class HealthProfileData {
  const HealthProfileData({
    this.birthDate,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.weightMeasuredAt,
    this.activeEnergyBurnedKcal,
    this.workouts = const [],
    this.failures = const [],
  });

  final DateTime? birthDate;
  final Gender? gender;
  final double? heightCm;
  final double? weightKg;

  /// 体重サンプルの測定時刻。取得処理の現在時刻ではない。
  final DateTime? weightMeasuredAt;
  final double? activeEnergyBurnedKcal;
  final List<HealthWorkoutRecord> workouts;

  /// 型ごとの失敗。成功して値が無い型はここには入らない。
  final List<HealthReadFailure> failures;

  static const empty = HealthProfileData();

  bool readFailed(String type) {
    for (final failure in failures) {
      if (failure.type == type) {
        return true;
      }
    }
    return false;
  }

  HealthProfileData copyWith({
    DateTime? birthDate,
    Gender? gender,
    double? heightCm,
    double? weightKg,
    DateTime? weightMeasuredAt,
    double? activeEnergyBurnedKcal,
    List<HealthWorkoutRecord>? workouts,
    List<HealthReadFailure>? failures,
  }) {
    return HealthProfileData(
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      weightMeasuredAt: weightMeasuredAt ?? this.weightMeasuredAt,
      activeEnergyBurnedKcal:
          activeEnergyBurnedKcal ?? this.activeEnergyBurnedKcal,
      workouts: workouts ?? this.workouts,
      failures: failures ?? this.failures,
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
