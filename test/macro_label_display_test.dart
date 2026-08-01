import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/macro_field.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/saved_food/publish_saved_food_confirmation_screen.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/utils/history_grouping.dart';
import 'package:ayg/utils/macro_display.dart';
import 'package:ayg/widgets/common/compact_macro_display.dart';
import 'package:ayg/widgets/history/food_history_list.dart';
import 'package:ayg/widgets/saved_food/public_food_match_card.dart';
import 'package:ayg/widgets/saved_food/saved_food_meal_quantity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final referenceDate = DateTime(2026, 7, 21);
  final now = DateTime(2026, 7, 21, 12);

  OpenFoodFactsService createOpenFoodFactsService() {
    return OpenFoodFactsService(userAgent: 'AYG-Test/1.0 (test@example.com)');
  }

  SavedFood sampleFood() {
    return SavedFood(
      foodId: 'food-1',
      ownerUserId: 'test-user-id',
      name: 'テスト食品',
      normalizedName: 'テスト食品',
      baseAmount: 100,
      unitType: FoodUnitType.g,
      kcalPerBase: 200,
      proteinPerBase: 10,
      fatPerBase: 5,
      carbPerBase: 30,
      sourceType: FoodSourceType.manual,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('macro display labels', () {
    test('formatters use formal Japanese macro names', () {
      expect(macroFieldLabel(MacroField.protein), AppStrings.macroProtein);
      expect(macroFieldLabel(MacroField.fat), AppStrings.macroFat);
      expect(macroFieldLabel(MacroField.carb), AppStrings.macroCarb);
      expect(
        formatMacroSummaryInline(proteinG: 10, fatG: 5, carbG: 30),
        'タンパク質 10g · 脂質 5g · 炭水化物 30g',
      );
    });

    testWidgets('home shows formal macro labels', (tester) async {
      final controller = AppController(
        nutritionEngine: NutritionEngine(),
        healthRepository: MockHealthRepository(isAvailable: false),
      );
      controller.setProfile(
        UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 175,
          weightKg: 75,
        ),
      );
      controller.setNutritionSettings(
        const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
      );
      controller.setGoal(
        Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
      );
      await controller.addFood(
        FoodEntry(
          id: 'food-1',
          name: '朝食',
          kcalPerUnit: 500,
          proteinPerUnit: 20,
          fatPerUnit: 10,
          carbPerUnit: 60,
          quantity: 1,
          loggedAt: now,
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(
            controller: controller,
            openFoodFactsService: createOpenFoodFactsService(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text(AppStrings.macroProtein), findsOneWidget);
      expect(find.text(AppStrings.macroFat), findsOneWidget);
      expect(find.text(AppStrings.macroCarb), findsOneWidget);
      expect(find.text('P'), findsNothing);
      expect(find.text('F'), findsNothing);
      expect(find.text('C'), findsNothing);
      controller.dispose();
    });

    testWidgets('food history shows formal macro labels', (tester) async {
      final entry = FoodEntry(
        id: 'food-1',
        name: '昼食',
        kcalPerUnit: 400,
        proteinPerUnit: 25,
        fatPerUnit: 12,
        carbPerUnit: 45,
        quantity: 1,
        loggedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: FoodHistoryList(
              dateGroups: [
                HistoryDateGroup(
                  date: now,
                  label: '今日',
                  items: [entry],
                ),
              ],
              onTapEntry: (_) {},
              onDeleteEntry: (_) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('タンパク質 25g'), findsOneWidget);
      expect(find.textContaining('脂質 12g'), findsOneWidget);
      expect(find.textContaining('炭水化物 45g'), findsOneWidget);
      expect(find.textContaining('P '), findsNothing);
    });

    testWidgets('public food match card shows formal macro labels', (
      tester,
    ) async {
      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );
      final food = sampleFood().copyWith(
        ownerUserId: 'other-user',
        visibility: FoodVisibility.public,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: PublicFoodMatchCard(
              controller: controller,
              food: food,
              goodCount: 1,
              badCount: 0,
            ),
          ),
        ),
      );

      expect(find.textContaining('タンパク質 10g'), findsOneWidget);
      expect(find.textContaining('脂質 5g'), findsOneWidget);
      expect(find.textContaining('炭水化物 30g'), findsOneWidget);
      controller.dispose();
    });

    testWidgets('quantity sheet shows formal macro labels', (tester) async {
      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );
      final food = sampleFood();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      showSavedFoodMealQuantitySheet(
                        context: context,
                        controller: controller,
                        food: food,
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.macroNutritionInfoLabel), findsOneWidget);
      expect(find.textContaining('タンパク質 10g'), findsWidgets);
      expect(find.textContaining('炭水化物 30g'), findsWidgets);
      controller.dispose();
    });

    testWidgets('publish confirmation shows formal macro labels', (
      tester,
    ) async {
      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PublishSavedFoodConfirmationScreen(
            controller: controller,
            food: sampleFood(),
            validationErrors: const [],
            manualMacroConsistent: true,
          ),
        ),
      );

      expect(find.text(AppStrings.macroProtein), findsOneWidget);
      expect(find.text(AppStrings.macroFat), findsOneWidget);
      expect(find.text(AppStrings.macroCarb), findsOneWidget);
      controller.dispose();
    });

    testWidgets('compact macro display does not overflow on narrow width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 480));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: CompactMacroDisplay(
                kcal: 200,
                proteinG: 10,
                fatG: 5,
                carbG: 30,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('タンパク質 10g'), findsOneWidget);
      expect(find.textContaining('炭水化物 30g'), findsOneWidget);
    });

    test('nutrition engine totals are unchanged after label update', () {
      final engine = NutritionEngine();
      final summary = engine.calculateDailySummary(
        profile: UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 175,
          weightKg: 75,
        ),
        settings: const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
        goal: Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: referenceDate.add(const Duration(days: 90)),
        ),
        foodEntries: [
          FoodEntry(
            id: '1',
            name: 'Test',
            kcalPerUnit: 500,
            proteinPerUnit: 20,
            fatPerUnit: 10,
            carbPerUnit: 60,
            quantity: 1,
            loggedAt: now,
          ),
        ],
        exerciseEntries: const [],
        referenceDate: referenceDate,
      );

      expect(summary.intakeProteinG, 20);
      expect(summary.intakeFatG, 10);
      expect(summary.intakeCarbG, 60);
      expect(summary.intakeKcal, 500);
    });
  });
}
