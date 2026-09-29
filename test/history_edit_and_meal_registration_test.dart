import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/utils/history_grouping.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('history editing support', () {
    test('groupExerciseEntriesByDate filters selected day only', () {
      final reference = DateTime(2026, 8, 1, 12);
      final entries = [
        ExerciseEntry(
          id: 'today',
          name: 'Walk',
          durationMin: 30,
          burnedKcal: 100,
          loggedAt: DateTime(2026, 8, 1, 9),
        ),
        ExerciseEntry(
          id: 'yesterday',
          name: 'Run',
          durationMin: 20,
          burnedKcal: 200,
          loggedAt: DateTime(2026, 7, 31, 9),
        ),
      ];

      final groups = groupExerciseEntriesByDate(
        entries,
        referenceDate: reference,
        todayOnly: true,
      );

      expect(groups, hasLength(1));
      expect(groups.first.items, hasLength(1));
      expect(groups.first.items.first.id, 'today');
    });
  });

  group('registerFoodMealFromDrafts', () {
    test(
      'creates grouped food entries without mutating template storage',
      () async {
        final controller = AppController();
        final loggedAt = DateTime(2026, 7, 20, 18, 30);

        await controller.registerFoodMealFromDrafts(
          mealGroupName: '朝食セット',
          loggedAt: loggedAt,
          items: const [
            MealTemplateItemDraft(
              name: 'ヨーグルト',
              baseAmount: 1,
              unitType: FoodUnitType.serving,
              kcalPerBase: 80,
              proteinPerBase: 4,
              fatPerBase: 2,
              carbPerBase: 10,
              consumedAmount: 1,
              sortOrder: 1,
            ),
            MealTemplateItemDraft(
              name: 'バナナ',
              baseAmount: 1,
              unitType: FoodUnitType.piece,
              kcalPerBase: 90,
              proteinPerBase: 1,
              fatPerBase: 0.2,
              carbPerBase: 23,
              consumedAmount: 2,
              sortOrder: 2,
            ),
          ],
        );

        expect(controller.foodEntries, hasLength(2));
        expect(
          controller.foodEntries.every(
            (entry) =>
                entry.mealGroupName == '朝食セット' &&
                entry.mealGroupId != null &&
                entry.loggedAt == loggedAt,
          ),
          isTrue,
        );
        expect(
          controller.foodEntries.map((entry) => entry.name),
          containsAll(['ヨーグルト', 'バナナ']),
        );
      },
    );

    test('updateFood preserves entry id when loggedAt changes', () async {
      final controller = AppController();
      final original = DateTime(2026, 7, 10, 8);
      final updated = DateTime(2026, 7, 11, 9);

      await controller.addFood(
        FoodEntry(
          id: controller.generateId(),
          name: 'テスト',
          kcalPerBase: 100,
          baseAmount: 1,
          unitType: FoodUnitType.serving,
          consumedAmount: 1,
          sourceType: FoodEntrySource.manual,
          loggedAt: original,
        ),
      );
      final existing = controller.foodEntries.single;

      await controller.updateFood(
        existing.copyWith(loggedAt: updated, kcalPerBase: 120),
      );

      expect(controller.foodEntries, hasLength(1));
      expect(controller.foodEntries.single.id, existing.id);
      expect(controller.foodEntries.single.loggedAt, updated);
      expect(controller.foodEntries.single.kcalPerBase, 120);
    });
  });
}
