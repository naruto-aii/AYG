import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/workout_template.dart';
import 'package:ayg/services/search_suggestion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = SearchSuggestionService();

  group('SearchSuggestionService', () {
    test('ranks saved foods by use count then recency', () {
      final now = DateTime(2026, 8, 1);
      final ranked = service.rankSavedFoodSuggestions([
        SavedFood(
          foodId: 'a',
          ownerUserId: 'user',
          name: 'Alpha',
          normalizedName: 'alpha',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          useCount: 1,
          lastUsedAt: now.subtract(const Duration(days: 2)),
          createdAt: now,
          updatedAt: now,
        ),
        SavedFood(
          foodId: 'b',
          ownerUserId: 'user',
          name: 'Beta',
          normalizedName: 'beta',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          useCount: 3,
          lastUsedAt: now.subtract(const Duration(days: 1)),
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      expect(ranked.first.name, 'Beta');
    });

    test('ranks meal templates with stable tie-breaker', () {
      final now = DateTime(2026, 8, 1);
      final ranked = service.rankMealTemplateSuggestions([
        MealTemplate(
          templateId: 'b',
          ownerUserId: 'user',
          name: 'B',
          normalizedName: 'b',
          totalKcal: 100,
          totalProteinG: 5,
          totalFatG: 2,
          totalCarbG: 10,
          useCount: 1,
          createdAt: now,
          updatedAt: now,
        ),
        MealTemplate(
          templateId: 'a',
          ownerUserId: 'user',
          name: 'A',
          normalizedName: 'a',
          totalKcal: 100,
          totalProteinG: 5,
          totalFatG: 2,
          totalCarbG: 10,
          useCount: 1,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      expect(ranked.first.normalizedName, 'a');
    });

    test('ranks workout templates by use count', () {
      final now = DateTime(2026, 8, 1);
      final ranked = service.rankWorkoutTemplateSuggestions([
        WorkoutTemplate(
          templateId: 'low',
          ownerUserId: 'user',
          name: 'Low',
          normalizedName: 'low',
          useCount: 1,
          createdAt: now,
          updatedAt: now,
        ),
        WorkoutTemplate(
          templateId: 'high',
          ownerUserId: 'user',
          name: 'High',
          normalizedName: 'high',
          useCount: 5,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      expect(ranked.first.name, 'High');
    });
  });
}
