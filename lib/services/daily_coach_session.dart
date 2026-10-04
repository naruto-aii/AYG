import '../data/coach_food_catalog.dart';
import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../repositories/coach_nutrition_source.dart';
import '../state/app_controller.dart';
import 'daily_coach.dart';

enum DailyCoachStatus { ready, nutritionMissing }

class DailyCoachLoadResult {
  const DailyCoachLoadResult({
    required this.status,
    this.meals = const [],
    this.exerciseMessage,
  });

  final DailyCoachStatus status;
  final List<CoachMealProposal> meals;
  final String? exerciseMessage;
}

class DailyCoachSession {
  DailyCoachSession({
    required this.controller,
    CoachNutritionSource? nutritionSource,
  }) : nutritionSource = nutritionSource ?? SupabaseCoachNutritionSource();

  final AppController controller;
  final CoachNutritionSource nutritionSource;

  Future<DailyCoachLoadResult> load(DateTime now) async {
    final summary = controller.summary;
    if (summary == null) {
      return const DailyCoachLoadResult(
        status: DailyCoachStatus.nutritionMissing,
      );
    }

    final List<CoachFoodStock> stocks;
    try {
      stocks = await nutritionSource.load();
    } catch (_) {
      return const DailyCoachLoadResult(
        status: DailyCoachStatus.nutritionMissing,
      );
    }
    if (stocks.isEmpty) {
      return const DailyCoachLoadResult(
        status: DailyCoachStatus.nutritionMissing,
      );
    }

    final excluded = <String>{
      for (final entry in controller.foodEntries)
        if (entry.officialFoodCode != null &&
            coachLoggedWithinDays(entry.loggedAt, now, 3))
          entry.officialFoodCode!,
    };
    final weight = controller.currentWeightSelection.kg;
    return DailyCoachLoadResult(
      status: DailyCoachStatus.ready,
      meals: planCoachMeals(
        foods: stocks,
        excludedFoodCodes: excluded,
        remainingKcal: summary.remainingKcal,
        remainingProteinG: summary.targetProteinG - summary.intakeProteinG,
        remainingFatG: summary.targetFatG - summary.intakeFatG,
        remainingCarbG: summary.targetCarbG - summary.intakeCarbG,
      ),
      exerciseMessage: buildCoachExerciseMessage(
        overageKcal: summary.calorieOverageKcal,
        weightKg: weight > 0 ? weight : null,
        exercises: controller.exerciseEntries,
        now: now,
      ),
    );
  }

  Future<void> save(CoachMealProposal proposal) async {
    if (proposal.components.isEmpty) {
      return;
    }
    final loggedAt = DateTime.now();
    final mealGroupId = controller.generateId();
    final entries = <FoodEntry>[];
    for (var i = 0; i < proposal.components.length; i++) {
      final item = proposal.components[i];
      entries.add(
        FoodEntry(
          id: controller.generateId(),
          name: item.displayName,
          kcalPerBase: item.kcalPerUnit,
          proteinPerBase: item.proteinPerUnit,
          fatPerBase: item.fatPerUnit,
          carbPerBase: item.carbPerUnit,
          baseAmount: 1,
          unitType: FoodUnitType.serving,
          consumedAmount: item.units.toDouble(),
          sourceType: FoodEntrySource.mextSfct,
          officialFoodCode: item.foodCode,
          officialFoodName: item.officialName,
          mealGroupId: mealGroupId,
          mealGroupName: proposal.headline,
          sortOrder: i + 1,
          loggedAt: loggedAt,
        ),
      );
    }
    await controller.addFoodEntriesBatch(entries);
  }
}
