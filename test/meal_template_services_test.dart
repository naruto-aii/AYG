import 'package:ayg/models/meal_template_apply.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/services/meal_template_apply_service.dart';
import 'package:ayg/services/meal_template_totals_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MealTemplateTotalsService', () {
    const service = MealTemplateTotalsService();
    final now = DateTime(2026, 7, 20);

    test('100g -> 150g scales totals', () {
      final totals = service.totalsFromItems([
        MealTemplateItem(
          itemId: '1',
          name: 'Rice',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          kcalPerBase: 200,
          consumedAmount: 150,
          sortOrder: 1,
          snapshotSavedAt: now,
        ),
      ]);
      expect(totals.kcal, 300);
    });
  });

  group('MealTemplateApplyService', () {
    const service = MealTemplateApplyService();
    final now = DateTime(2026, 7, 20);

    test('buildEntries shares mealGroupId and sortOrder', () {
      var counter = 0;
      final entries = service.buildEntries(
        items: [
          MealTemplateItem(
            itemId: '1',
            name: 'A',
            baseAmount: 100,
            unitType: FoodUnitType.g,
            kcalPerBase: 100,
            consumedAmount: 100,
            sortOrder: 1,
            snapshotSavedAt: now,
          ),
          MealTemplateItem(
            itemId: '2',
            name: 'B',
            baseAmount: 1,
            unitType: FoodUnitType.piece,
            kcalPerBase: 50,
            consumedAmount: 2,
            sortOrder: 2,
            snapshotSavedAt: now,
          ),
        ],
        mealGroupId: 'group-1',
        mealGroupName: 'Lunch',
        loggedAt: now,
        generateEntryId: () => 'entry-${counter++}',
      );

      expect(entries, hasLength(2));
      expect(entries.every((entry) => entry.mealGroupId == 'group-1'), isTrue);
      expect(entries.first.mealGroupName, 'Lunch');
      expect(entries.last.totalKcal, 100);
    });

    test('resolveItems excludes cancelled template apply', () {
      final resolved = service.resolveItems(
        originalItems: [
          MealTemplateItem(
            itemId: '1',
            name: 'A',
            baseAmount: 1,
            unitType: FoodUnitType.serving,
            consumedAmount: 1,
            sortOrder: 1,
            snapshotSavedAt: now,
          ),
        ],
        resolutions: const [
          MealTemplateItemResolution(
            itemId: '1',
            action: MealTemplateItemResolutionAction.cancel,
          ),
        ],
      );
      expect(resolved, isEmpty);
    });
  });
}
