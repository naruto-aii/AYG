import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/macro_field.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/services/macro_nutrition_consistency_policy.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/food/macro_nutrition_input_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FoodFormScreen manual entry', () {
    testWidgets('reconciles inconsistent values before save', (
      WidgetTester tester,
    ) async {
      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );
      final service = OpenFoodFactsService(
        userAgent: 'AYG/test (test@example.com)',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FoodFormScreen(
                            controller: controller,
                            openFoodFactsService: service,
                          ),
                        ),
                      );
                    },
                    child: const Text('open form'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('open form'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('food_name_field')),
        'テスト食品',
      );
      await tester.enterText(
        find.byKey(const ValueKey('macro_field_kcal')),
        '200',
      );
      await tester.enterText(
        find.byKey(const ValueKey('macro_field_protein')),
        '10',
      );
      await tester.enterText(
        find.byKey(const ValueKey('macro_field_fat')),
        '5',
      );
      await tester.enterText(
        find.byKey(const ValueKey('macro_field_carb')),
        '10',
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();

      expect(controller.foodEntries, hasLength(1));
      expect(controller.foodEntries.first.name, 'テスト食品');
      expect(controller.foodEntries.first.kcalPerUnit, 125);
      expect(controller.foodEntries.first.sourceType, FoodEntrySource.manual);
    });
  });

  group('OFF food entry snapshot', () {
    test('preserves OFF kcal and sourceType without nutrition edit', () {
      final macroInput = MacroNutritionInputController();
      macroInput.applyExternalValues(
        kcal: 539,
        protein: 6.3,
        fat: 30.9,
        carb: 57.5,
      );

      expect(macroInput.prepareForSave(), isTrue);

      final entry = FoodEntry(
        id: 'off-1',
        name: 'Nutella',
        kcalPerUnit: macroInput.parseOptional(MacroField.kcal),
        proteinPerUnit: macroInput.parseOptional(MacroField.protein),
        fatPerUnit: macroInput.parseOptional(MacroField.fat),
        carbPerUnit: macroInput.parseOptional(MacroField.carb),
        sourceType: MacroNutritionConsistencyPolicy.resolveSaveSourceType(
          initialSourceType: FoodEntrySource.openFoodFacts,
          nutritionEditedByUser: macroInput.nutritionEditedByUser,
        ),
        loggedAt: DateTime(2026, 7, 21),
      );

      expect(entry.kcalPerUnit, 539);
      expect(entry.totalKcal, 539);
      expect(entry.sourceType, FoodEntrySource.openFoodFacts);
      macroInput.dispose();
    });

    test('switches to manual sourceType after nutrition edit', () {
      final macroInput = MacroNutritionInputController();
      macroInput.applyExternalValues(
        kcal: 539,
        protein: 6.3,
        fat: 30.9,
        carb: 57.5,
      );

      macroInput.kcalController.text = '540';
      macroInput.onFieldChanged(MacroField.kcal);
      expect(macroInput.prepareForSave(), isTrue);

      final sourceType = MacroNutritionConsistencyPolicy.resolveSaveSourceType(
        initialSourceType: FoodEntrySource.openFoodFacts,
        nutritionEditedByUser: macroInput.nutritionEditedByUser,
      );

      expect(sourceType, FoodEntrySource.manual);
      macroInput.dispose();
    });

    test('copied savedFood keeps values until edited', () {
      final macroInput = MacroNutritionInputController();
      macroInput.initializeFromNullable(
        kcal: 300,
        protein: 20,
        fat: 10,
        carb: 30,
        consistencyMode: MacroNutritionConsistencyPolicy.initialModeFor(
          FoodEntrySource.savedFood,
        ),
      );

      expect(macroInput.kcalController.text, '300');
      expect(macroInput.autoField, isNull);
      expect(macroInput.canSave, isTrue);

      final sourceType = MacroNutritionConsistencyPolicy.resolveSaveSourceType(
        initialSourceType: FoodEntrySource.savedFood,
        nutritionEditedByUser: macroInput.nutritionEditedByUser,
      );
      expect(sourceType, FoodEntrySource.savedFood);
      macroInput.dispose();
    });
  });
}
