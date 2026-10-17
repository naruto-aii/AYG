import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/calculation/calorie_target_mode.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/coach_nutrition_source.dart';
import 'package:ayg/repositories/coach_slot_store.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/settings/daily_calculation_explanation_screen.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/share_card_content.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/utils/kcal_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

/// 10.4 + 10.4 は行ごとに 10 で、合計 20。生の合計 20.8 を引いた残りを丸めると 1 ずれる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const target = 2000.0;

  FoodEntry food(String id, double kcal) {
    return FoodEntry(
      id: id,
      name: id,
      kcalPerBase: kcal,
      loggedAt: DateTime.now(),
    );
  }

  AppController controllerWith(List<FoodEntry> foods, {ExerciseEntry? exercise}) {
    final controller = AppController(
      nutritionEngine: NutritionEngine(),
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
        calorieTargetMode: CalorieTargetMode.manual,
        manualTargetKcal: target,
        manualProteinG: 100,
        manualFatG: 60,
        manualCarbG: 250,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 70,
        targetDate: DateTime(2026, 12, 31),
      ),
    );
    controller.foodEntries.addAll(foods);
    if (exercise != null) {
      controller.exerciseEntries.add(exercise);
    }
    controller.refreshDailySummary();
    return controller;
  }

  test('remaining is target plus rounded burn minus rounded intake', () {
    final foods = [food('a', 10.4), food('b', 10.4)];
    final exercise = ExerciseEntry(
      id: 'swim',
      name: '水泳',
      durationMin: 30,
      burnedKcal: 10.6,
      loggedAt: DateTime.now(),
      netKcal: 10.6,
    );
    final day = displayedDayKcal(
      targetKcal: target,
      foods: foods,
      alcohol: const <AlcoholEntry>[],
      exercises: [exercise],
      healthExcessKcal: 10.6,
    );

    expect(day.intake, 20);
    expect(day.burn, 22);
    expect(day.remaining, 2002);
    final rawRemaining = target + 10.6 + 10.6 - (10.4 + 10.4);
    expect(rawRemaining.round(), isNot(day.remaining));
    expect(day.remaining, day.target + day.burn - day.intake);
  });

  test('overage uses the same integers when the raw sign disagrees', () {
    final day = displayedDayKcal(
      targetKcal: target,
      foods: [food('a', 1000.4), food('b', 1000.4)],
      alcohol: const <AlcoholEntry>[],
      exercises: const <ExerciseEntry>[],
    );
    expect(day.intake, 2000);
    expect(day.remaining, 0);
    expect(day.isOverage, isFalse);
    expect((target - (1000.4 + 1000.4)).isNegative, isTrue);
  });

  testWidgets('home, explanation, and share use the displayed remaining', (
    tester,
  ) async {
    final controller = controllerWith([food('a', 10.4), food('b', 10.4)]);
    addTearDown(controller.dispose);
    final shown = controller.displayedSummaryKcal(DateTime.now());
    expect(shown.remaining, 1980);
    expect(controller.summary!.remainingKcal.round(), isNot(1980));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1980'), findsOneWidget);
    expect(find.text('1979'), findsNothing);
    expect(find.text('20'), findsWidgets);

    await tester.tap(find.text('この数値の計算根拠'));
    await tester.pumpAndSettle();
    expect(find.byType(DailyCalculationExplanationScreen), findsOneWidget);
    expect(find.text('1980 kcal'), findsOneWidget);
    expect(find.text('20 kcal'), findsWidgets);

    final card = buildMealShareCard(
      summary: controller.summary!,
      day: DateTime.now(),
      intakeKcal: shown.intake,
      targetKcal: shown.target,
      isOverage: shown.isOverage,
    );
    expect(card.figure, '20 / 2,000');
    expect(card.isOverage, isFalse);
  });

  test('widget figures and the coach plan use that same remaining', () async {
    final controller = controllerWith([
      food('a', 10.4),
      food('b', 10.4),
    ]);
    addTearDown(controller.dispose);
    final shown = controller.displayedSummaryKcal(DateTime.now());
    final figures = mealWidgetFiguresFromDisplayed(shown);
    expect(figures.intakeKcal, 20);
    expect(figures.burnKcal, 0);
    expect(figures.targetKcal, 2000);
    expect(figures.remainingKcal, 1980);
    expect(figures.overageKcal, isNull);
    expect(
      figures.targetKcal! + figures.burnKcal! - figures.intakeKcal!,
      figures.remainingKcal,
    );

    final session = DailyCoachSession(
      controller: controller,
      slotStore: MemoryCoachSlotStore(),
      nutritionSource: _FixedNutrition(CoachFoodCatalog.stocks),
    );
    final loaded = await session.load(DateTime.now());
    expect(loaded.plans, isNotEmpty);
    expect(loaded.plans.first.remainingKcal, 1980);
  });
}

class _FixedNutrition implements CoachNutritionSource {
  _FixedNutrition(this.stocks);

  final List<CoachFoodStock> stocks;

  @override
  Future<List<CoachFoodStock>> load() async => stocks;
}
