import 'package:ayg/models/food_form_suggestion.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/widgets/food/food_form_suggestion_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'FoodFormSuggestionList shows distinct sections for food and template',
    (tester) async {
      final now = DateTime(2026, 8, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FoodFormSuggestionList(
              formatSavedFoodBaseLabel: (_) => '100g',
              suggestions: [
                SavedFoodFormSuggestion(
                  SavedFood(
                    foodId: 'f1',
                    ownerUserId: 'user',
                    name: 'Apple',
                    normalizedName: 'apple',
                    baseAmount: 100,
                    unitType: FoodUnitType.g,
                    useCount: 2,
                    createdAt: now,
                    updatedAt: now,
                  ),
                ),
                MealTemplateFormSuggestion(
                  MealTemplate(
                    templateId: 't1',
                    ownerUserId: 'user',
                    name: 'Lunch Set',
                    normalizedName: 'lunch set',
                    totalKcal: 500,
                    totalProteinG: 30,
                    totalFatG: 15,
                    totalCarbG: 60,
                    useCount: 4,
                    createdAt: now,
                    updatedAt: now,
                  ),
                  itemCount: 3,
                ),
              ],
              onSavedFoodSelected: (_) {},
              onMealTemplateSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('保存済み食品'), findsOneWidget);
      expect(find.text('食事テンプレート'), findsOneWidget);
      expect(find.text('Apple'), findsOneWidget);
      expect(find.text('Lunch Set'), findsOneWidget);
      expect(find.textContaining('3品'), findsOneWidget);
      expect(find.byIcon(Icons.restaurant_outlined), findsOneWidget);
      expect(find.byIcon(Icons.library_books_outlined), findsOneWidget);
    },
  );
}
