import 'dart:math' as math;

import '../data/coach_food_catalog.dart';
import '../data/met_activity_catalog.dart';
import 'personal_coach_planner.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import '../services/exercise_calorie_calculator.dart';
import '../utils/local_date.dart';
import '../utils/meal_slot.dart';

const coachNutritionMissingMessage = '食品の数値が取れませんでした。';

/// 直近 [days] 日（今日を含む）に記録したか。7日は見ない。
bool coachLoggedWithinDays(DateTime loggedAt, DateTime now, int days) {
  if (days <= 0) {
    return false;
  }
  final start = localDayStart(now).subtract(Duration(days: days - 1));
  final day = DateTime(loggedAt.year, loggedAt.month, loggedAt.day);
  return !day.isBefore(start);
}

class CoachMealComponent {
  const CoachMealComponent({
    required this.foodCode,
    required this.displayName,
    required this.officialName,
    required this.units,
    required this.grams,
    required this.kcalPerUnit,
    required this.proteinPerUnit,
    required this.fatPerUnit,
    required this.carbPerUnit,
    this.portionNote,
  });

  final String foodCode;
  final String displayName;
  final String? officialName;

  /// グラム以外の目安（「2個」「1丁の半分」、中身の説明）。無ければ null。
  final String? portionNote;

  /// 提案単位の数。食事記録の数量はこの数で、あとから変えられる。
  final int units;
  final int grams;
  final double kcalPerUnit;
  final double proteinPerUnit;
  final double fatPerUnit;
  final double carbPerUnit;
}

class CoachMealProposal {
  const CoachMealProposal({
    required this.headline,
    required this.components,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    this.macroNote,
    this.note,
    this.bandLabel,
    this.slotLabel,
    this.slot,
  });

  final String headline;
  final List<CoachMealComponent> components;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final String? macroNote;

  /// 「残りは次の食事で」など、案の補足。
  final String? note;

  /// 間食、軽食、一食（ちゃんと）、一食（しっかり）。
  final String? bandLabel;

  /// 1日の案での枠（朝食・昼食・間食・夕食）。
  final String? slotLabel;

  /// 1日の案での枠。登録した枠を、開き直したときの案から外すのに使う。
  final MealSlot? slot;

  Set<String> get foodCodes => {for (final item in components) item.foodCode};
}

/// 提案グラムを、変えたグラムに合わせて食事記録の数量へ直す。
///
/// 数量は提案単位の数。150g の 1 単位を 100g にするなら 100/150。
double? coachMealConsumedAmount({
  required int units,
  required int proposedGrams,
  required double editedGrams,
}) {
  if (units <= 0 ||
      proposedGrams <= 0 ||
      !editedGrams.isFinite ||
      editedGrams <= 0) {
    return null;
  }
  final amount = units * editedGrams / proposedGrams;
  if (!amount.isFinite || amount <= 0) {
    return null;
  }
  return amount;
}

/// 登録欄の数字。0 以下や空は登録しない。
double? parseCoachAmount(String raw) {
  final text = raw.trim().replaceAll(',', '');
  if (text.isEmpty) {
    return null;
  }
  final value = double.tryParse(text);
  if (value == null || !value.isFinite || value <= 0) {
    return null;
  }
  return value;
}

/// 分は整数で記録する。小数は登録しない。
int? coachWholeMinutes(double amount) {
  if (!amount.isFinite || amount <= 0) {
    return null;
  }
  final nearest = amount.roundToDouble();
  if ((amount - nearest).abs() > 0.001) {
    return null;
  }
  final minutes = nearest.toInt();
  if (minutes < 1 || minutes >= 24 * 60) {
    return null;
  }
  return minutes;
}

/// 1日の残りを、これからの食事と間食に分けた案。
class CoachDayPlan {
  const CoachDayPlan({
    required this.meals,
    required this.remainingKcal,
    this.note,
  });

  /// 朝食・昼食・間食・夕食の順。1件ずつ登録する。
  final List<CoachMealProposal> meals;
  final double remainingKcal;
  final String? note;

  double get kcal => meals.fold(0.0, (sum, meal) => sum + meal.kcal);
}

/// 残りを今の時刻からとれる食事に分ける。上位 [limit] 通り。
///
/// 0〜10時台は朝食・昼食・間食・夕食、11〜14時台は昼食・間食・夕食、
/// 15〜21時台は夕食だけ、22時以降は間食だけ。残りが1食分（450kcal）未満なら1回分だけ。
List<CoachDayPlan> planCoachDay({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  required DateTime now,
  int limit = 5,
  Set<MealSlot> skipSlots = const {},
}) {
  final days = planPersonalCoachDay(
    foods: foods,
    excludedFoodCodes: excludedFoodCodes,
    remainingKcal: remainingKcal,
    now: now,
    limit: limit,
    skipSlots: skipSlots,
  );
  return [
    for (final day in days)
      CoachDayPlan(
        remainingKcal: remainingKcal,
        note: coachDayPlanNote(day, now),
        meals: [
          for (final entry in day.meals)
            _proposal(
              foods,
              entry.meal,
              slotLabel: entry.label,
              slot: entry.slot,
            ),
        ],
      ),
  ];
}

/// 案の下に出す一文。この時間帯の案で埋めきれない残りがあるときだけ。
///
/// 1食の上限に届かない端数（調味料の分の余白）には出さない。
String? coachDayPlanNote(PlannedCoachDay day, DateTime now) {
  final leftover = day.leftoverKcal.round();
  if (leftover < 100) {
    return null;
  }
  if (personalCoachIsLateEvening(now)) {
    return '夜遅い時間なので、間食までにしています。残りは無理に食べなくて大丈夫です。';
  }
  if (!day.hitsMealCap) {
    return null;
  }
  return '1食は850kcalまでにしています。この案を全部食べると、残りは約${leftover}kcalです。';
}

CoachMealProposal _proposal(
  List<CoachFoodStock> foods,
  PlannedCoachMeal meal, {
  String? slotLabel,
  MealSlot? slot,
  String? note,
}) {
  return CoachMealProposal(
    headline: meal.headline,
    bandLabel: personalCoachBandLabel(meal.band),
    slotLabel: slotLabel,
    slot: slot,
    note: note,
    components: [
      for (final item in meal.items)
        CoachMealComponent(
          foodCode: item.foodCode,
          displayName: item.displayName,
          officialName: item.displayName,
          units: 1,
          grams: item.grams,
          kcalPerUnit: _componentKcal(foods, item),
          proteinPerUnit: item.proteinG,
          fatPerUnit: item.fatG,
          carbPerUnit: item.carbG,
          portionNote: coachPortionNote(item),
        ),
    ],
    kcal: meal.kcal.toDouble(),
    proteinG: meal.proteinG,
    fatG: meal.fatG,
    carbG: meal.carbG,
  );
}

/// 食品の横に出す、グラム以外の目安。「200g」のようにグラムだけなら出さない。
String? coachPortionNote(PlannedCoachItem item) {
  final parts = <String>[
    if (item.label.trim().isNotEmpty && item.label.trim() != '${item.grams}g')
      item.label.trim(),
    if (item.contentsNote != null && item.contentsNote!.trim().isNotEmpty)
      item.contentsNote!.trim(),
  ];
  if (parts.isEmpty) {
    return null;
  }
  return parts.join('・');
}

/// 上位10案。量は食品ごとの選択肢だけ。unit_grams では増やさない。
List<CoachMealProposal> planCoachMeals({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  required double remainingProteinG,
  required double remainingFatG,
  required double remainingCarbG,
  DateTime? now,
  int limit = 10,
}) {
  final planned = planPersonalCoachMeals(
    foods: foods,
    excludedFoodCodes: excludedFoodCodes,
    remainingKcal: remainingKcal,
    now: now,
    limit: limit,
  );
  final late = now != null && personalCoachIsLateEvening(now);
  final note = remainingKcal > 850 && !late ? '残りは次の食事で' : null;
  return [
    for (final meal in planned) _proposal(foods, meal, note: note),
  ];
}

double _componentKcal(List<CoachFoodStock> foods, PlannedCoachItem item) {
  for (final food in foods) {
    if (food.candidate.foodCode == item.foodCode) {
      return food.kcalFor(item.grams);
    }
  }
  return item.kcal.toDouble();
}

class _Practice {
  const _Practice({
    required this.activity,
    required this.longestMinutes,
    required this.longestKm,
    required this.paceKmh,
    required this.met,
    required this.latest,
  });

  final MetActivityDefinition activity;
  final int longestMinutes;
  final double longestKm;
  final double? paceKmh;
  final double met;
  final DateTime latest;
}

enum CoachExerciseUnit { kilometers, minutes }

/// 超過の日に出す運動。登録できるのは、文に書いた今日の量。
class CoachExerciseProposal {
  const CoachExerciseProposal({
    required this.message,
    this.activityId,
    this.amount,
    this.unit,
    this.met,
    this.paceKmh,
    this.needsWeight = false,
  });

  final String message;
  final String? activityId;

  /// そのまま登録する量。km または分。体重が無い日は null。
  final double? amount;
  final CoachExerciseUnit? unit;

  /// 分で計算したときの MET。距離の種目では使わない。
  final double? met;

  /// 距離の種目を分で登録するとき、その人の速さ。無ければ種目の基準速度。
  final double? paceKmh;

  /// 体重が無く、登録の前に体重の記録が要る。
  final bool needsWeight;

  bool get canRegister {
    return activityId != null &&
        activityId!.isNotEmpty &&
        unit != null &&
        amount != null &&
        amount!.isFinite &&
        amount! > 0;
  }

  String get unitLabel => unit == CoachExerciseUnit.kilometers ? 'km' : '分';
}

class _ExercisePlan {
  const _ExercisePlan(
    this.message, {
    this.activityId,
    this.amount,
    this.unit,
    this.met,
    this.paceKmh,
    this.needsWeight = false,
  });

  final String message;
  final String? activityId;
  final double? amount;
  final CoachExerciseUnit? unit;
  final double? met;
  final double? paceKmh;
  final bool needsWeight;

  CoachExerciseProposal get proposal {
    return CoachExerciseProposal(
      message: message,
      activityId: activityId,
      amount: amount,
      unit: unit,
      met: met,
      paceKmh: paceKmh,
      needsWeight: needsWeight,
    );
  }
}

/// 超過を戻す運動。超過が無い日は null。
///
/// 今すぐの量は、その種目の直近30日で一番長い記録の1.5倍まで、かつ45分以内。
/// やったことが無い人は、歩くか軽い自重で20分まで。
/// 体重が無い日は距離を出さない。登録もしない。
CoachExerciseProposal? buildCoachExerciseProposal({
  required double overageKcal,
  required double? weightKg,
  required List<ExerciseEntry> exercises,
  required DateTime now,
}) {
  return _exercisePlan(
    overageKcal: overageKcal,
    weightKg: weightKg,
    exercises: exercises,
    now: now,
  )?.proposal;
}

String? buildCoachExerciseMessage({
  required double overageKcal,
  required double? weightKg,
  required List<ExerciseEntry> exercises,
  required DateTime now,
}) {
  return buildCoachExerciseProposal(
    overageKcal: overageKcal,
    weightKg: weightKg,
    exercises: exercises,
    now: now,
  )?.message;
}

_ExercisePlan? _exercisePlan({
  required double overageKcal,
  required double? weightKg,
  required List<ExerciseEntry> exercises,
  required DateTime now,
}) {
  if (!overageKcal.isFinite || overageKcal <= 0) {
    return null;
  }
  if (overageKcal < 50) {
    return const _ExercisePlan('今日はほぼちょうどです。');
  }
  if (personalCoachIsNight(now)) {
    return const _ExercisePlan('明日の歩数で取り戻しましょう。');
  }
  final practice = _bestPractice(exercises, now);
  final weight = weightKg != null && weightKg > 0 ? weightKg : null;
  if (weight == null) {
    return const _ExercisePlan(
      '体重が未登録のため、戻るカロリーを計算できません。',
      needsWeight: true,
    );
  }
  final requiredRunKm = overageKcal / weight;
  if (practice == null) {
    return _noviceMessage(
      overageKcal: overageKcal,
      weightKg: weight,
      requiredRunKm: requiredRunKm,
    );
  }
  final factor = practice.activity.netKcalPerKgKm;
  if (factor != null && practice.longestKm > 0) {
    final distance = _distanceMessage(
      practice: practice,
      overageKcal: overageKcal,
      weightKg: weight,
      requiredRunKm: requiredRunKm,
      factor: factor,
    );
    if (distance != null) {
      return distance;
    }
  }
  if (practice.longestMinutes > 0) {
    final timed = _durationMessage(
      practice: practice,
      overageKcal: overageKcal,
      weightKg: weight,
      requiredRunKm: requiredRunKm,
    );
    if (timed != null) {
      return timed;
    }
  }
  return _noviceMessage(
    overageKcal: overageKcal,
    weightKg: weight,
    requiredRunKm: requiredRunKm,
  );
}

/// 画面の数字を、その種目の式で運動記録にする。
ExerciseEntry? coachExerciseEntry({
  required CoachExerciseProposal proposal,
  required double amount,
  required double? weightKg,
  required String id,
  required DateTime loggedAt,
}) {
  if (!proposal.canRegister || !amount.isFinite || amount <= 0) {
    return null;
  }
  final activity = MetActivityCatalog.findById(proposal.activityId);
  final weight = weightKg;
  if (activity == null ||
      activity.lifestyleIncluded ||
      activity.requiresManualKcal ||
      activity.calorieFormula == null ||
      weight == null ||
      weight <= 0) {
    return null;
  }
  const calculator = ExerciseCalorieCalculator();
  switch (proposal.unit!) {
    case CoachExerciseUnit.minutes:
      if (activity.quantityUnit == ExerciseQuantityUnit.distanceKm) {
        final speed = proposal.paceKmh ?? activity.referenceSpeedKmh;
        if (speed == null || speed <= 0) {
          return null;
        }
        return _coachDistanceEntry(
          activity: activity,
          distanceKm: amount / 60 * speed,
          weightKg: weight,
          id: id,
          loggedAt: loggedAt,
          calculator: calculator,
        );
      }
      if (activity.quantityUnit != ExerciseQuantityUnit.durationMin) {
        return null;
      }
      final minutes = coachWholeMinutes(amount);
      final met = proposal.met ?? activity.defaultMet;
      if (minutes == null || met <= 1) {
        return null;
      }
      final estimate = calculator.estimate(
        met: met,
        weightKg: weight,
        durationMinutes: minutes,
        sourceKey: activity.sourceKey,
      );
      if (estimate == null) {
        return null;
      }
      return ExerciseEntry(
        id: id,
        name: activity.displayName,
        durationMin: minutes,
        burnedKcal: estimate.grossKcal,
        loggedAt: loggedAt,
        category: activity.category,
        activityId: activity.id,
        intensity: activity.defaultIntensityId,
        metValue: met,
        grossKcal: estimate.grossKcal,
        netKcal: estimate.netKcal,
        weightKgSnapshot: weight,
        calculationSource: estimate.calculationSource,
        calculationVersion: estimate.calculationVersion,
        sourceKey: activity.sourceKey,
      );
    case CoachExerciseUnit.kilometers:
      if (activity.quantityUnit != ExerciseQuantityUnit.distanceKm) {
        return null;
      }
      return _coachDistanceEntry(
        activity: activity,
        distanceKm: amount,
        weightKg: weight,
        id: id,
        loggedAt: loggedAt,
        calculator: calculator,
      );
  }
}

ExerciseEntry? _coachDistanceEntry({
  required MetActivityDefinition activity,
  required double distanceKm,
  required double weightKg,
  required String id,
  required DateTime loggedAt,
  required ExerciseCalorieCalculator calculator,
}) {
  final factor = activity.netKcalPerKgKm;
  final estimate = factor != null
      ? calculator.estimateByDistanceFactor(
          weightKg: weightKg,
          distanceKm: distanceKm,
          netKcalPerKgKm: factor,
          sourceKey: activity.sourceKey,
        )
      : activity.referenceSpeedKmh == null
      ? null
      : calculator.estimateByDistanceSpeed(
          met: activity.defaultMet,
          weightKg: weightKg,
          distanceKm: distanceKm,
          speedKmh: activity.referenceSpeedKmh!,
          sourceKey: activity.sourceKey,
        );
  if (estimate == null) {
    return null;
  }
  return ExerciseEntry(
    id: id,
    name: activity.displayName,
    durationMin: ExerciseCalorieCalculator.companionDurationMin(
      distanceKm: distanceKm,
      referenceSpeedKmh: activity.referenceSpeedKmh,
    ),
    burnedKcal: estimate.grossKcal,
    loggedAt: loggedAt,
    category: activity.category,
    activityId: activity.id,
    intensity: activity.defaultIntensityId,
    distanceKm: distanceKm,
    metValue: factor == null ? activity.defaultMet : null,
    grossKcal: estimate.grossKcal,
    netKcal: estimate.netKcal,
    weightKgSnapshot: weightKg,
    calculationSource: estimate.calculationSource,
    calculationVersion: estimate.calculationVersion,
    sourceKey: activity.sourceKey,
  );
}

_Practice? _bestPractice(List<ExerciseEntry> exercises, DateTime now) {
  final groups = <String, List<ExerciseEntry>>{};
  for (final entry in exercises) {
    if (!coachLoggedWithinDays(entry.loggedAt, now, 30)) {
      continue;
    }
    final activity = MetActivityCatalog.findById(entry.activityId);
    if (activity == null ||
        activity.lifestyleIncluded ||
        activity.requiresManualKcal) {
      continue;
    }
    groups.putIfAbsent(activity.id, () => []).add(entry);
  }

  _Practice? selected;
  for (final group in groups.values) {
    final activity = MetActivityCatalog.findById(group.first.activityId);
    if (activity == null) {
      continue;
    }
    var longestMinutes = 0;
    var longestKm = 0.0;
    var met = activity.defaultMet;
    var latest = group.first.loggedAt;
    ExerciseEntry? longestDistance;
    for (final entry in group) {
      if (entry.durationMin > longestMinutes) {
        longestMinutes = entry.durationMin;
        final recordedMet = entry.metValue;
        if (recordedMet != null && recordedMet > 1) {
          met = recordedMet;
        }
      }
      final km = entry.distanceKm ?? 0;
      if (km > longestKm) {
        longestKm = km;
        longestDistance = entry;
      }
      if (!entry.loggedAt.isBefore(latest)) {
        latest = entry.loggedAt;
      }
    }
    final pace = longestDistance == null ? null : _paceKmh(longestDistance);
    if (longestMinutes <= 0 && longestKm <= 0) {
      continue;
    }
    final practice = _Practice(
      activity: activity,
      longestMinutes: longestMinutes,
      longestKm: longestKm,
      paceKmh: pace,
      met: met,
      latest: latest,
    );
    if (selected == null || _outranks(practice, selected)) {
      selected = practice;
    }
  }
  return selected;
}

bool _outranks(_Practice next, _Practice current) {
  if (next.longestMinutes != current.longestMinutes) {
    return next.longestMinutes > current.longestMinutes;
  }
  if (next.longestKm != current.longestKm) {
    return next.longestKm > current.longestKm;
  }
  return next.latest.isAfter(current.latest);
}

double? _paceKmh(ExerciseEntry entry) {
  final km = entry.distanceKm;
  if (km == null || km <= 0 || entry.durationMin <= 0) {
    return null;
  }
  final kmh = km / entry.durationMin * 60;
  if (kmh < 3 || kmh > 25) {
    return null;
  }
  return kmh;
}

_ExercisePlan _noviceMessage({
  required double overageKcal,
  required double weightKg,
  required double requiredRunKm,
}) {
  final walk = MetActivityCatalog.findById('walk_brisk');
  final speed = walk?.referenceSpeedKmh;
  final factor = walk?.netKcalPerKgKm;
  if (walk == null || speed == null || speed <= 0 || factor == null) {
    return const _ExercisePlan('今日やるなら、速歩きで20分までにします。');
  }
  final perMinute = factor * weightKg * speed / 60;
  return _timedPlan(
    activity: walk,
    activityName: '速歩き',
    overageKcal: overageKcal,
    perMinute: perMinute,
    capMinutes: 20,
    paceKmh: speed,
  );
}

_ExercisePlan? _distanceMessage({
  required _Practice practice,
  required double overageKcal,
  required double weightKg,
  required double requiredRunKm,
  required double factor,
}) {
  final pace = practice.paceKmh ?? practice.activity.referenceSpeedKmh;
  if (pace == null || pace <= 0) {
    return null;
  }
  final perMinute = factor * weightKg * pace / 60;
  if (perMinute <= 0) {
    return null;
  }
  var cap = 45.0;
  if (practice.longestMinutes > 0) {
    cap = math.min(cap, practice.longestMinutes * 1.5);
  }
  if (practice.longestKm > 0) {
    cap = math.min(cap, practice.longestKm * 1.5 / pace * 60);
  }
  return _timedPlan(
    activity: practice.activity,
    activityName: practice.activity.displayName,
    overageKcal: overageKcal,
    perMinute: perMinute,
    capMinutes: cap,
    paceKmh: pace,
    met: practice.activity.quantityUnit == ExerciseQuantityUnit.durationMin
        ? practice.met
        : null,
  );
}

_ExercisePlan? _durationMessage({
  required _Practice practice,
  required double overageKcal,
  required double weightKg,
  required double requiredRunKm,
}) {
  if (practice.activity.quantityUnit == ExerciseQuantityUnit.distanceKm &&
      practice.activity.netKcalPerKgKm == null &&
      practice.longestKm <= 0) {
    return null;
  }
  final perMinute = const ExerciseCalorieCalculator()
      .estimate(met: practice.met, weightKg: weightKg, durationMinutes: 1)
      ?.netKcal;
  if (perMinute == null || perMinute <= 0) {
    return null;
  }
  var cap = 45.0;
  if (practice.longestMinutes > 0) {
    cap = math.min(cap, practice.longestMinutes * 1.5);
  }
  final speed = practice.paceKmh ?? practice.activity.referenceSpeedKmh;
  if (practice.longestKm > 0 && speed != null && speed > 0) {
    cap = math.min(cap, practice.longestKm * 1.5 / speed * 60);
  }
  if (practice.met <= 1) {
    return _ExercisePlan(
      _timeMessage(
        activityName: practice.activity.displayName,
        neededMinutes: (overageKcal / perMinute).round(),
        todayMinutes: math.max(1, math.min(overageKcal / perMinute, cap).round()),
        recoveredKcal: 0,
        overageKcal: overageKcal,
      ),
    );
  }
  return _timedPlan(
    activity: practice.activity,
    activityName: practice.activity.displayName,
    overageKcal: overageKcal,
    perMinute: perMinute,
    capMinutes: cap,
    met: practice.activity.quantityUnit == ExerciseQuantityUnit.durationMin
        ? practice.met
        : null,
    paceKmh: practice.activity.quantityUnit == ExerciseQuantityUnit.distanceKm
        ? speed
        : null,
  );
}

_ExercisePlan _timedPlan({
  required MetActivityDefinition activity,
  required String activityName,
  required double overageKcal,
  required double perMinute,
  required double capMinutes,
  double? paceKmh,
  double? met,
}) {
  final needed = overageKcal / perMinute;
  final today = math.min(needed, math.max(1, capMinutes));
  final shown = math.max(1, today.round());
  final recovered = (perMinute * shown).round();
  final distanceWithoutSpeed =
      activity.quantityUnit == ExerciseQuantityUnit.distanceKm &&
      (paceKmh == null || paceKmh <= 0) &&
      (activity.referenceSpeedKmh == null || activity.referenceSpeedKmh! <= 0);
  if (distanceWithoutSpeed) {
    return _ExercisePlan(
      _timeMessage(
        activityName: activityName,
        neededMinutes: needed.round(),
        todayMinutes: shown,
        recoveredKcal: recovered,
        overageKcal: overageKcal,
      ),
    );
  }
  return _ExercisePlan(
    _timeMessage(
      activityName: activityName,
      neededMinutes: needed.round(),
      todayMinutes: shown,
      recoveredKcal: recovered,
      overageKcal: overageKcal,
    ),
    activityId: activity.id,
    amount: shown.toDouble(),
    unit: CoachExerciseUnit.minutes,
    met: met,
    paceKmh: paceKmh,
  );
}

String _timeMessage({
  required String activityName,
  required int neededMinutes,
  required int todayMinutes,
  required int recoveredKcal,
  required double overageKcal,
}) {
  final needed = math.max(1, neededMinutes);
  final today = math.max(1, todayMinutes);
  final recovered = math.max(0, recoveredKcal);
  final rest = math.max(0, overageKcal.round() - recovered);
  final todayLine = '$today分で約${recovered}kcal戻ります。';
  if (needed <= today && rest <= 0) {
    return '今日やるなら$activityNameで$today分にします。$todayLine';
  }
  final limit = today < needed ? 'までにします' : 'にします';
  final tail = rest > 0 ? '残りの約${rest}kcalは明日以降の食事で。' : '';
  return '戻すには$activityNameで約$needed分です。今日やるなら$today分$limit。$todayLine$tail';
}

/// kcal の表示。3桁ごとにカンマ（2,438）。
String formatCoachKcal(int kcal) {
  final negative = kcal < 0;
  final digits = kcal.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

String formatCoachAmount(double value) {
  if (!value.isFinite || value <= 0) {
    return '';
  }
  return _formatKm(value);
}

String _formatKm(double km) {
  final scaled = (km * 10).round();
  if (scaled <= 0) {
    return '0.1';
  }
  final whole = scaled ~/ 10;
  final tenth = scaled.abs() % 10;
  if (tenth == 0) {
    return whole.toString();
  }
  return '$whole.$tenth';
}
