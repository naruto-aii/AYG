import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/utils/history_grouping.dart';
import 'package:ayg/utils/meal_slot.dart';

void main() {
  final referenceDate = DateTime(2026, 7, 21, 12);

  group('mealSlotFromTime', () {
    test('maps hours to meal slots', () {
      expect(mealSlotFromTime(DateTime(2026, 1, 1, 8)), MealSlot.breakfast);
      expect(mealSlotFromTime(DateTime(2026, 1, 1, 12)), MealSlot.lunch);
      expect(mealSlotFromTime(DateTime(2026, 1, 1, 19)), MealSlot.dinner);
      expect(mealSlotFromTime(DateTime(2026, 1, 1, 16)), MealSlot.snack);
    });
  });

  group('groupFoodEntriesByDate', () {
    test('groups today entries only by default', () {
      final entries = [
        FoodEntry(
          id: '1',
          name: '今日',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 21, 8),
        ),
        FoodEntry(
          id: '2',
          name: '昨日',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 20, 8),
        ),
      ];

      final groups = groupFoodEntriesByDate(
        entries,
        referenceDate: referenceDate,
      );

      expect(groups, hasLength(1));
      expect(groups.first.label, '今日');
      expect(groups.first.items, hasLength(1));
    });
  });

  group('groupFoodEntriesByMealSlot', () {
    test('returns all meal slots in display order', () {
      final entries = [
        FoodEntry(
          id: '1',
          name: '朝',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 21, 8),
        ),
      ];

      final groups = groupFoodEntriesByMealSlot(entries);

      expect(groups, hasLength(4));
      expect(groups.first.slot, MealSlot.breakfast);
      expect(groups.first.entries, hasLength(1));
      expect(groups[1].entries, isEmpty);
    });
  });

  group('groupExerciseEntriesByDate', () {
    test('groups today exercises only by default', () {
      final entries = [
        ExerciseEntry(
          id: '1',
          name: '走る',
          durationMin: 30,
          burnedKcal: 200,
          loggedAt: DateTime(2026, 7, 21, 7),
        ),
      ];

      final groups = groupExerciseEntriesByDate(
        entries,
        referenceDate: referenceDate,
      );

      expect(groups, hasLength(1));
      expect(groups.first.label, '今日');
    });
  });
}
