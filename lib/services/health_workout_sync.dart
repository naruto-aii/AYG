import '../models/health_profile_data.dart';

const healthWorkoutIdMaxLength = 128;
const healthWorkoutActivityMaxLength = 128;

const healthWorkoutColumns = <String>[
  'user_id',
  'workout_id',
  'activity_type',
  'started_at',
  'ended_at',
  'calories_burned',
  'advertising_use',
];

/// 端末がすでに保存している Health ワークアウトだけを表の行にする。
/// 歩数、距離、レシート、トークンは入れない。消費カロリーが無い行は null のまま。
Map<String, dynamic>? healthWorkoutRow({
  required String userId,
  required HealthWorkoutRecord record,
}) {
  final workoutId = record.id.trim();
  final activityType = record.activityType.trim();
  if (workoutId.isEmpty || workoutId.length > healthWorkoutIdMaxLength) {
    return null;
  }
  if (activityType.isEmpty ||
      activityType.length > healthWorkoutActivityMaxLength) {
    return null;
  }
  if (record.endTime.isBefore(record.startTime)) {
    return null;
  }
  final calories = record.caloriesBurned;
  if (calories != null && calories < 0) {
    return null;
  }

  return {
    'user_id': userId,
    'workout_id': workoutId,
    'activity_type': activityType,
    'started_at': record.startTime.toUtc().toIso8601String(),
    'ended_at': record.endTime.toUtc().toIso8601String(),
    'calories_burned': calories,
    'advertising_use': false,
  };
}

HealthWorkoutRecord healthWorkoutFromRow(Map<String, dynamic> row) {
  return HealthWorkoutRecord(
    id: row['workout_id'] as String,
    activityType: row['activity_type'] as String,
    startTime: DateTime.parse(row['started_at'] as String),
    endTime: DateTime.parse(row['ended_at'] as String),
    caloriesBurned: (row['calories_burned'] as num?)?.toDouble(),
  );
}
