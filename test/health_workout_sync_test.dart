import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/services/health_workout_sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores the workout numbers Health already returned', () {
    final start = DateTime.utc(2026, 10, 3, 1);
    final end = DateTime.utc(2026, 10, 3, 1, 30);
    final row = healthWorkoutRow(
      userId: 'user-1',
      record: HealthWorkoutRecord(
        id: '100_200',
        activityType: 'RUNNING',
        startTime: start,
        endTime: end,
        caloriesBurned: 180.5,
      ),
    );

    expect(row, isNotNull);
    expect(row!.keys.toSet(), healthWorkoutColumns.toSet());
    expect(row['advertising_use'], isFalse);
    expect(row['calories_burned'], 180.5);
    expect(row.containsKey('receipt'), isFalse);
    expect(row.containsKey('token'), isFalse);
    expect(row.containsKey('steps'), isFalse);
    expect(row.containsKey('distance_km'), isFalse);

    final parsed = healthWorkoutFromRow(row);
    expect(parsed.id, '100_200');
    expect(parsed.activityType, 'RUNNING');
    expect(parsed.caloriesBurned, 180.5);
    expect(parsed.startTime, start);
    expect(parsed.endTime, end);
  });

  test('keeps a missing calorie empty and drops numbers the app did not accept', () {
    final missing = healthWorkoutRow(
      userId: 'user-1',
      record: HealthWorkoutRecord(
        id: '1_2',
        activityType: 'WALKING',
        startTime: DateTime.utc(2026, 10, 3),
        endTime: DateTime.utc(2026, 10, 3, 0, 20),
      ),
    );
    expect(missing?['calories_burned'], isNull);

    expect(
      healthWorkoutRow(
        userId: 'user-1',
        record: HealthWorkoutRecord(
          id: '1_2',
          activityType: 'WALKING',
          startTime: DateTime.utc(2026, 10, 3, 2),
          endTime: DateTime.utc(2026, 10, 3, 1),
          caloriesBurned: 10,
        ),
      ),
      isNull,
    );
    expect(
      healthWorkoutRow(
        userId: 'user-1',
        record: HealthWorkoutRecord(
          id: '1_2',
          activityType: 'WALKING',
          startTime: DateTime.utc(2026, 10, 3),
          endTime: DateTime.utc(2026, 10, 3, 1),
          caloriesBurned: -1,
        ),
      ),
      isNull,
    );
  });
}
