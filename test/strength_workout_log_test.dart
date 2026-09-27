import 'package:ayg/models/exercise_category.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/strength_workout_log.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StrengthNotesCodec', () {
    test('roundtrips multiple exercises and sets with memo', () {
      const log = StrengthWorkoutLog(
        exercises: [
          StrengthExerciseLog(
            name: 'ベンチプレス',
            sets: [
              StrengthSetLog(weightKg: 60, reps: 10),
              StrengthSetLog(weightKg: 62.5, reps: 8),
            ],
          ),
          StrengthExerciseLog(
            name: 'スクワット',
            sets: [StrengthSetLog(weightKg: 80, reps: 5)],
          ),
        ],
      );

      final encoded = StrengthNotesCodec.encode(log: log, memo: '脚が重い');
      final parsed = StrengthNotesCodec.parse(encoded);

      expect(parsed.memo, '脚が重い');
      expect(parsed.log, isNotNull);
      expect(parsed.log!.exercises, hasLength(2));
      expect(parsed.log!.exercises.first.name, 'ベンチプレス');
      expect(parsed.log!.exercises.first.sets, hasLength(2));
      expect(parsed.log!.exercises.last.name, 'スクワット');
      expect(parsed.log!.totalSets, 3);
      expect(parsed.log!.summary, contains('ベンチプレス 2セット'));
      expect(parsed.log!.summary, contains('スクワット 1セット 80kg×5'));
    });

    test('plain memo stays plain memo', () {
      final parsed = StrengthNotesCodec.parse('ただのメモ');
      expect(parsed.log, isNull);
      expect(parsed.memo, 'ただのメモ');
      expect(StrengthNotesCodec.encode(memo: 'ただのメモ'), 'ただのメモ');
    });
  });

  group('ExerciseStrengthDetails', () {
    test('falls back to legacy sets reps weight', () {
      final entry = ExerciseEntry(
        id: 'legacy',
        name: '筋トレ',
        durationMin: 40,
        burnedKcal: 200,
        loggedAt: DateTime(2026, 9, 1),
        category: ExerciseCategory.strength,
        sets: 3,
        reps: 10,
        liftWeightKg: 60,
      );

      expect(entry.strengthLog, isNotNull);
      expect(entry.strengthLog!.exercises.single.sets, hasLength(3));
      expect(entry.strengthSummary, contains('筋トレ 3セット 60kg×10'));
    });
  });
}
