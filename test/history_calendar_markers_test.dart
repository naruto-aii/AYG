import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/utils/history_calendar_markers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildHistoryDayMarkers', () {
    test('marks food, exercise, alcohol independently', () {
      final markers = buildHistoryDayMarkers(
        foodEntries: [
          FoodEntry(
            id: 'f1',
            name: '朝食',
            quantity: 1,
            loggedAt: DateTime(2026, 7, 20, 8),
          ),
        ],
        exerciseEntries: [
          ExerciseEntry(
            id: 'e1',
            name: '走る',
            durationMin: 30,
            burnedKcal: 200,
            loggedAt: DateTime(2026, 7, 20, 18),
          ),
          ExerciseEntry(
            id: 'e2',
            name: '筋トレ',
            durationMin: 20,
            burnedKcal: 100,
            loggedAt: DateTime(2026, 7, 21, 7),
          ),
        ],
        alcoholEntries: [
          AlcoholEntry(
            id: 'a1',
            beverageName: 'ビール',
            amount: 500,
            unit: 'ml',
            alcoholPercentage: 5,
            totalCalories: 200,
            pureAlcoholGrams: 20,
            alcoholCalories: 140,
            consumedAt: DateTime(2026, 7, 22, 20),
          ),
        ],
      );

      final foodExerciseDay = DateTime(2026, 7, 20);
      final exerciseOnlyDay = DateTime(2026, 7, 21);
      final alcoholDay = DateTime(2026, 7, 22);

      expect(markers[foodExerciseDay]?.hasFood, isTrue);
      expect(markers[foodExerciseDay]?.hasExercise, isTrue);
      expect(markers[foodExerciseDay]?.hasAlcohol, isFalse);
      expect(markers[exerciseOnlyDay]?.hasExercise, isTrue);
      expect(markers[exerciseOnlyDay]?.hasFood, isFalse);
      expect(markers[alcoholDay]?.hasAlcohol, isTrue);
    });
  });
}
