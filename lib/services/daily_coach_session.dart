import '../data/coach_food_catalog.dart';
import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../repositories/coach_nutrition_source.dart';
import '../repositories/coach_slot_store.dart';
import '../state/app_controller.dart';
import '../utils/meal_slot.dart';
import 'daily_coach.dart';
import 'personal_coach_planner.dart';

enum DailyCoachStatus { ready, nutritionMissing }

/// その日に出すのは食事か運動のどちらか一方。
enum DailyCoachFocus { meals, exercise, none }

class DailyCoachLoadResult {
  const DailyCoachLoadResult({
    required this.status,
    this.meals = const [],
    this.plans = const [],
    this.exerciseMessage,
    this.exercise,
    this.focus,
    this.message,
    this.registered = const [],
  });

  final DailyCoachStatus status;

  /// 今日これからの枠のうち、もう登録した枠（時間の順）。案には入れず「登録済み」と出す。
  final List<CoachRegisteredSlot> registered;
  /// 1回分の案（ほかの案で切り替える）。[plans] があるときは使わない。
  final List<CoachMealProposal> meals;

  /// 今日これからの食事に分けた案（ほかの案で切り替える）。
  final List<CoachDayPlan> plans;
  final String? exerciseMessage;
  final CoachExerciseProposal? exercise;

  /// 未指定のときは、入っている方だけを出す。両方入っているときは出さない。
  final DailyCoachFocus? focus;

  /// 食事も運動も出さないときの一文。
  final String? message;

  /// 画面に出す案。[plans] が無ければ [meals] を1回分の案として包む。
  List<CoachDayPlan> get dayPlans {
    if (plans.isNotEmpty) {
      return plans;
    }
    return [
      for (final meal in meals)
        CoachDayPlan(meals: [meal], remainingKcal: meal.kcal, note: meal.note),
    ];
  }

  bool get offersMeals {
    if (status != DailyCoachStatus.ready || (meals.isEmpty && plans.isEmpty)) {
      return false;
    }
    if (focus == DailyCoachFocus.exercise || focus == DailyCoachFocus.none) {
      return false;
    }
    if (focus == DailyCoachFocus.meals) {
      return true;
    }
    return exercise == null &&
        (exerciseMessage == null || exerciseMessage!.trim().isEmpty);
  }

  bool get offersExercise {
    if (status != DailyCoachStatus.ready || _exerciseText.isEmpty) {
      return false;
    }
    if (focus == DailyCoachFocus.meals || focus == DailyCoachFocus.none) {
      return false;
    }
    if (focus == DailyCoachFocus.exercise) {
      return true;
    }
    return meals.isEmpty && plans.isEmpty;
  }

  String get _exerciseText {
    return (exercise?.message ?? exerciseMessage)?.trim() ?? '';
  }
}

class DailyCoachSession {
  DailyCoachSession({
    required this.controller,
    CoachNutritionSource? nutritionSource,
    CoachSlotStore? slotStore,
  }) : nutritionSource = nutritionSource ?? SupabaseCoachNutritionSource(),
       slotStore = slotStore ?? PreferencesCoachSlotStore();

  final AppController controller;
  final CoachNutritionSource nutritionSource;
  final CoachSlotStore slotStore;

  /// 今日これからの枠のうち、登録済みの枠。食事記録を消した枠は入れない。
  Future<List<CoachRegisteredSlot>> registeredSlots(DateTime now) async {
    if (personalCoachIsLateEvening(now)) {
      return const [];
    }
    final window = personalCoachRemainingSlots(now).toSet();
    final ids = {for (final entry in controller.foodEntries) entry.id};
    final saved = await slotStore.registeredOn(now);
    return [
      for (final slot in MealSlot.displayOrder.where(window.contains))
        for (final item in saved)
          if (item.slot == slot &&
              (item.entryIds.isEmpty || item.entryIds.any(ids.contains)))
            item,
    ];
  }

  Future<DailyCoachLoadResult> load(DateTime now) async {
    final summary = controller.summary;
    if (summary == null) {
      return const DailyCoachLoadResult(
        status: DailyCoachStatus.nutritionMissing,
      );
    }

    final remaining = summary.remainingKcal;
    if (!remaining.isFinite) {
      return const DailyCoachLoadResult(
        status: DailyCoachStatus.nutritionMissing,
      );
    }
    if (remaining < 0) {
      final weight = controller.currentWeightSelection.kg;
      final overage = summary.calorieOverageKcal > 0
          ? summary.calorieOverageKcal
          : remaining.abs();
      final exercise = buildCoachExerciseProposal(
        overageKcal: overage,
        weightKg: weight > 0 ? weight : null,
        exercises: controller.exerciseEntries,
        now: now,
      );
      return DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.exercise,
        exercise: exercise,
        exerciseMessage: exercise?.message,
      );
    }
    if (remaining < 50) {
      return const DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.none,
        message: '今日はちょうどいいところです',
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
    // 登録した枠は外し、新しい残りで、まだの枠だけを組み直す。
    final registered = await registeredSlots(now);
    final plans = planCoachDay(
      foods: stocks,
      excludedFoodCodes: excluded,
      remainingKcal: remaining,
      now: now,
      skipSlots: {for (final item in registered) item.slot},
    );
    if (plans.isEmpty && registered.isNotEmpty) {
      return DailyCoachLoadResult(
        status: DailyCoachStatus.ready,
        focus: DailyCoachFocus.none,
        message: '今日これからの食事は、登録済みです。',
        registered: registered,
      );
    }
    return DailyCoachLoadResult(
      status: DailyCoachStatus.ready,
      focus: DailyCoachFocus.meals,
      plans: plans,
      registered: registered,
    );
  }

  /// [grams] は食品ごとの登録グラム。省略した欄は提案のグラム。
  /// 保存した食事の entry id を、登録した順で返す。
  Future<List<String>> saveMeal(
    CoachMealProposal proposal, {
    List<double>? grams,
  }) async {
    if (proposal.components.isEmpty) {
      return const [];
    }
    final loggedAt = DateTime.now();
    final mealGroupId = controller.generateId();
    final entries = <FoodEntry>[];
    for (var i = 0; i < proposal.components.length; i++) {
      final item = proposal.components[i];
      final edited = grams != null && i < grams.length
          ? grams[i]
          : item.grams.toDouble();
      final consumed = coachMealConsumedAmount(
        units: item.units,
        proposedGrams: item.grams,
        editedGrams: edited,
      );
      if (consumed == null) {
        throw StateError('coach meal amount');
      }
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
          consumedAmount: consumed,
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
    return [for (final entry in entries) entry.id];
  }

  /// 変えた [amount] で運動を記録する。記録できなければ false。
  Future<bool> saveExercise(
    CoachExerciseProposal proposal, {
    required double amount,
  }) async {
    final weight = controller.currentWeightSelection.kg;
    final entry = coachExerciseEntry(
      proposal: proposal,
      amount: amount,
      weightKg: weight > 0 ? weight : null,
      id: controller.generateId(),
      loggedAt: DateTime.now(),
    );
    if (entry == null) {
      return false;
    }
    await controller.addExercise(entry);
    return true;
  }
}
