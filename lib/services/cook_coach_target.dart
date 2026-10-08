import 'dart:math' as math;

import '../utils/meal_slot.dart';
import 'personal_coach_planner.dart';

/// 自炊コーチがこの1回に使う目標。kcal の分け方はパーソナルコーチの1日の案と同じ。
class CookCoachMealTarget {
  const CookCoachMealTarget({
    required this.slot,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.remainingKcal,
    required this.remainingProteinG,
    required this.remainingFatG,
    required this.remainingCarbG,
  });

  final MealSlot slot;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final double remainingKcal;
  final double remainingProteinG;
  final double remainingFatG;
  final double remainingCarbG;

  bool get canGenerate => kcal.isFinite && kcal >= 50;
}

/// 今の時刻から、これからの最初の食事。
MealSlot cookCoachDefaultSlot(DateTime now) {
  return personalCoachRemainingSlots(now).first;
}

/// [slot] に割り当てる kcal。食事の枠はプランナーの budgetKcal と同じ計算。
///
/// 朝・昼の間食は、食事の前に取り分ける分（50kcal 未満なら 0、最大 160kcal）。
/// 22時以降の間食は 200kcal まで。
double cookCoachSlotBudget({
  required double remainingKcal,
  required DateTime now,
  required MealSlot slot,
  Set<MealSlot> skipSlots = const {},
}) {
  if (!remainingKcal.isFinite || remainingKcal < 50) {
    return 0;
  }
  final budgets = cookCoachSlotBudgets(
    remainingKcal: remainingKcal,
    now: now,
    skipSlots: skipSlots,
  );
  final planned = budgets[slot];
  if (planned != null) {
    return planned;
  }
  if (slot == MealSlot.snack) {
    return math.min(remainingKcal, personalCoachSnackCapKcal);
  }
  return math.min(
    personalCoachEffectiveRemaining(remainingKcal, now),
    personalCoachMealCapKcal,
  );
}

/// 今の時刻からとれる枠ごとの kcal。食品の中身には依存しない。
Map<MealSlot, double> cookCoachSlotBudgets({
  required double remainingKcal,
  required DateTime now,
  Set<MealSlot> skipSlots = const {},
}) {
  if (!remainingKcal.isFinite || remainingKcal < 50) {
    return const {};
  }
  final slots = personalCoachPlannedSlots(now, skipSlots);
  final mealSlots = [
    for (final slot in slots)
      if (slot != MealSlot.snack) slot,
  ];
  if (mealSlots.isEmpty) {
    return {
      MealSlot.snack: math.min(remainingKcal, personalCoachSnackCapKcal),
    };
  }
  if (remainingKcal < personalCoachMealFloorKcal) {
    return {
      mealSlots.first: personalCoachEffectiveRemaining(remainingKcal, now),
    };
  }
  final hasSnack = slots.contains(MealSlot.snack);
  final count = math.max(
    1,
    math.min(
      mealSlots.length,
      (remainingKcal / personalCoachMealFloorKcal).floor(),
    ),
  );
  final chosen = _pickSlots(mealSlots, count);
  var reserve = hasSnack
      ? (remainingKcal - chosen.length * personalCoachMealFloorKcal)
            .clamp(0.0, personalCoachSnackReserveKcal)
            .toDouble()
      : 0.0;
  if (reserve < 50) {
    reserve = 0;
  }
  final budget = math.min(
    (remainingKcal - reserve) / chosen.length,
    personalCoachMealCapKcal,
  );
  return {
    for (final slot in chosen) slot: budget,
    if (reserve >= 50) MealSlot.snack: reserve,
  };
}

/// 残り PFC は、その食事の kcal が今日の残りに占める割合で分ける。
CookCoachMealTarget cookCoachMealTarget({
  required DateTime now,
  required MealSlot slot,
  required double remainingKcal,
  required double remainingProteinG,
  required double remainingFatG,
  required double remainingCarbG,
  Set<MealSlot> skipSlots = const {},
}) {
  final kcal = cookCoachSlotBudget(
    remainingKcal: remainingKcal,
    now: now,
    slot: slot,
    skipSlots: skipSlots,
  );
  final share = remainingKcal > 0
      ? (kcal / remainingKcal).clamp(0.0, 1.0)
      : 0.0;
  return CookCoachMealTarget(
    slot: slot,
    kcal: kcal,
    proteinG: _shareMacro(remainingProteinG, share),
    fatG: _shareMacro(remainingFatG, share),
    carbG: _shareMacro(remainingCarbG, share),
    remainingKcal: remainingKcal,
    remainingProteinG: remainingProteinG,
    remainingFatG: remainingFatG,
    remainingCarbG: remainingCarbG,
  );
}

double _shareMacro(double remaining, double share) {
  if (!remaining.isFinite || remaining <= 0 || share <= 0) {
    return 0;
  }
  return remaining * share;
}

List<MealSlot> _pickSlots(List<MealSlot> slots, int count) {
  if (count >= slots.length) {
    return slots;
  }
  if (count == 1) {
    return [slots.first];
  }
  return [slots.first, slots.last];
}
