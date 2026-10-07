import 'dart:math' as math;

import '../data/coach_food_catalog.dart';
import '../data/met_activity_catalog.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import '../services/exercise_calorie_calculator.dart';
import '../utils/local_date.dart';

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
  });

  final String foodCode;
  final String displayName;
  final String? officialName;

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
  });

  final String headline;
  final List<CoachMealComponent> components;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final String? macroNote;

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

class _Portion {
  const _Portion({required this.stock, required this.count});

  final CoachFoodStock stock;
  final int count;

  CoachFoodCandidate get food => stock.candidate;
}

class _Draft {
  const _Draft({required this.portions});

  final List<_Portion> portions;

  String get key {
    final codes = [for (final portion in portions) portion.food.foodCode]
      ..sort();
    return codes.join(',');
  }

  double get kcal => portions.fold(0.0, (sum, portion) {
    return sum + portion.stock.unitKcal * portion.count;
  });

  double get proteinG => portions.fold(0.0, (sum, portion) {
    return sum + portion.stock.unitProteinG * portion.count;
  });

  double get fatG => portions.fold(0.0, (sum, portion) {
    return sum + portion.stock.unitFatG * portion.count;
  });

  double get carbG => portions.fold(0.0, (sum, portion) {
    return sum + portion.stock.unitCarbG * portion.count;
  });

  int get grams => portions.fold(0, (sum, portion) {
    return sum + portion.food.unitGrams * portion.count;
  });
}

/// 残りkcalに近い案を3つ。同じ食品のグラム違いだけは並べない。
///
/// PFCがずれても出す。「今日は提案できません」は返さない。
List<CoachMealProposal> planCoachMeals({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  required double remainingProteinG,
  required double remainingFatG,
  required double remainingCarbG,
}) {
  final available = [
    for (final food in foods)
      if (!excludedFoodCodes.contains(food.candidate.foodCode) &&
          food.unitKcal.isFinite &&
          food.unitKcal > 0)
        food,
  ]..sort((a, b) => a.candidate.sortOrder.compareTo(b.candidate.sortOrder));
  if (available.isEmpty) {
    return const [];
  }

  final target = remainingKcal.isFinite ? math.max(0.0, remainingKcal) : 0.0;
  final bestByFoods = <String, _Draft>{};

  void consider(_Draft draft) {
    final current = bestByFoods[draft.key];
    if (current == null || _preferDraft(draft, current, target)) {
      bestByFoods[draft.key] = draft;
    }
  }

  for (final food in available) {
    final limit = _maxUnits(food.unitKcal, target);
    for (var count = 1; count <= limit; count++) {
      consider(
        _Draft(
          portions: [_Portion(stock: food, count: count)],
        ),
      );
    }
  }

  for (var i = 0; i < available.length; i++) {
    for (var j = i + 1; j < available.length; j++) {
      final first = available[i];
      final second = available[j];
      final firstLimit = _maxUnits(first.unitKcal, target);
      final secondLimit = _maxUnits(second.unitKcal, target);
      for (var a = 1; a <= firstLimit; a++) {
        for (var b = 1; b <= secondLimit; b++) {
          consider(
            _Draft(
              portions: [
                _Portion(stock: first, count: a),
                _Portion(stock: second, count: b),
              ],
            ),
          );
        }
      }
    }
  }

  final ranked = bestByFoods.values.toList()
    ..sort((a, b) {
      final gap = (a.kcal - target).abs().compareTo((b.kcal - target).abs());
      if (gap != 0) {
        return gap;
      }
      final size = a.portions.length.compareTo(b.portions.length);
      if (size != 0) {
        return size;
      }
      final grams = a.grams.compareTo(b.grams);
      if (grams != 0) {
        return grams;
      }
      return a.key.compareTo(b.key);
    });

  return [
    for (final draft in ranked.take(3))
      _proposal(
        draft,
        remainingProteinG: remainingProteinG,
        remainingFatG: remainingFatG,
        remainingCarbG: remainingCarbG,
      ),
  ];
}

int _maxUnits(double unitKcal, double target) {
  if (target <= 0 || unitKcal <= 0) {
    return 1;
  }
  return ((target / unitKcal).ceil() + 1).clamp(1, 8);
}

bool _preferDraft(_Draft next, _Draft current, double target) {
  final nextGap = (next.kcal - target).abs();
  final currentGap = (current.kcal - target).abs();
  if ((nextGap - currentGap).abs() > 0.01) {
    return nextGap < currentGap;
  }
  if (next.portions.length != current.portions.length) {
    return next.portions.length < current.portions.length;
  }
  return next.grams < current.grams;
}

CoachMealProposal _proposal(
  _Draft draft, {
  required double remainingProteinG,
  required double remainingFatG,
  required double remainingCarbG,
}) {
  final portions = [...draft.portions]
    ..sort((a, b) => a.food.sortOrder.compareTo(b.food.sortOrder));
  final components = [
    for (final portion in portions)
      CoachMealComponent(
        foodCode: portion.food.foodCode,
        displayName: portion.food.displayName,
        officialName: portion.stock.nutrition.officialName,
        units: portion.count,
        grams: portion.food.unitGrams * portion.count,
        kcalPerUnit: portion.stock.unitKcal,
        proteinPerUnit: portion.stock.unitProteinG,
        fatPerUnit: portion.stock.unitFatG,
        carbPerUnit: portion.stock.unitCarbG,
      ),
  ];
  return CoachMealProposal(
    headline: _headline(portions),
    components: components,
    kcal: draft.kcal,
    proteinG: draft.proteinG,
    fatG: draft.fatG,
    carbG: draft.carbG,
    macroNote: _macroNote(
      proteinG: draft.proteinG,
      fatG: draft.fatG,
      carbG: draft.carbG,
      remainingProteinG: remainingProteinG,
      remainingFatG: remainingFatG,
      remainingCarbG: remainingCarbG,
    ),
  );
}

String _headline(List<_Portion> portions) {
  if (portions.length == 1) {
    final portion = portions.single;
    final food = portion.food;
    final grams = food.unitGrams * portion.count;
    if (food.foodCode == '01111') {
      return '${food.displayName}（${portion.count}個${grams}g、中身は米だけ）';
    }
    final counter = food.counter;
    if (counter != null) {
      return '${food.displayName}（${portion.count}$counter）';
    }
    return '${food.displayName}（${grams}g）';
  }

  final codes = {for (final portion in portions) portion.food.foodCode};
  final title =
      codes.length == 2 && codes.contains('01088') && codes.contains('12005')
      ? '卵かけご飯'
      : portions.map((portion) => portion.food.titleName).join('と');
  final detail = portions.map(_amountPhrase).join('と');
  return '$title（$detail）';
}

String _amountPhrase(_Portion portion) {
  final food = portion.food;
  final grams = food.unitGrams * portion.count;
  if (food.foodCode == '01111') {
    return '${food.amountName}${portion.count}${food.counter}${grams}g（中身は米だけ）';
  }
  final counter = food.counter;
  if (counter != null) {
    return '${food.amountName}${portion.count}$counter';
  }
  return '${food.amountName}${grams}g';
}

String? _macroNote({
  required double proteinG,
  required double fatG,
  required double carbG,
  required double remainingProteinG,
  required double remainingFatG,
  required double remainingCarbG,
}) {
  var name = 'たんぱく質';
  var gap = proteinG - remainingProteinG;
  final others = <(String, double)>[
    ('脂質', fatG - remainingFatG),
    ('炭水化物', carbG - remainingCarbG),
  ];
  for (final other in others) {
    if (other.$2.abs() > gap.abs()) {
      name = other.$1;
      gap = other.$2;
    }
  }
  final rounded = gap.round();
  if (rounded == 0) {
    return null;
  }
  final direction = rounded > 0 ? '多く' : '少なく';
  return 'これだと$nameが約${rounded.abs()}g$directionなります。今提案できる範囲で最善です。';
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
  });

  final String message;
  final String? activityId;

  /// そのまま登録する量。km または分。体重が無い日は null。
  final double? amount;
  final CoachExerciseUnit? unit;

  /// 分で計算したときの MET。距離の種目では使わない。
  final double? met;

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
  });

  final String message;
  final String? activityId;
  final double? amount;
  final CoachExerciseUnit? unit;
  final double? met;

  CoachExerciseProposal get proposal {
    return CoachExerciseProposal(
      message: message,
      activityId: activityId,
      amount: amount,
      unit: unit,
      met: met,
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
  final practice = _bestPractice(exercises, now);
  final weight = weightKg != null && weightKg > 0 ? weightKg : null;
  if (weight == null) {
    return _withoutWeight(practice);
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
        final speed = activity.referenceSpeedKmh;
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

_ExercisePlan _withoutWeight(_Practice? practice) {
  const head = '体重がないため、距離は出していません。';
  if (practice == null || practice.longestMinutes <= 0) {
    return const _ExercisePlan('$head今日やるなら、歩くか軽い自重で20分までにします。');
  }
  final cap = math.min(45.0, practice.longestMinutes * 1.5);
  final minutes = math.max(1, cap.round());
  return _ExercisePlan(
    '$head今日やるなら${practice.activity.displayName}$minutes分までにします。',
  );
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
    return const _ExercisePlan('今日やるなら、歩くか軽い自重で20分までにします。');
  }
  final neededKm = overageKcal / (factor * weightKg);
  final neededMin = neededKm / speed * 60;
  final today = math.min(20.0, neededMin);
  final shown = math.max(1, today.round());
  final message = neededMin > 45
      ? _partialReturn(
          requiredRunKm: requiredRunKm,
          today: '、歩くか軽い自重で20分までにします',
        )
      : '今日やるなら、歩くか軽い自重で$shown分${today + 0.05 < neededMin ? 'までにします' : 'にします'}。';
  return _ExercisePlan(
    message,
    activityId: walk.id,
    amount: shown.toDouble(),
    unit: CoachExerciseUnit.minutes,
  );
}

_ExercisePlan? _distanceMessage({
  required _Practice practice,
  required double overageKcal,
  required double weightKg,
  required double requiredRunKm,
  required double factor,
}) {
  final neededKm = overageKcal / (factor * weightKg);
  final caps = <double>[practice.longestKm * 1.5];
  final pace = practice.paceKmh ?? practice.activity.referenceSpeedKmh;
  double? neededMin;
  if (pace != null && pace > 0) {
    caps.add(pace * 45 / 60);
    neededMin = neededKm / pace * 60;
  }
  var todayKm = neededKm;
  for (final cap in caps) {
    if (cap < todayKm) {
      todayKm = cap;
    }
  }
  if (todayKm <= 0) {
    return null;
  }
  final exceeds = neededMin != null
      ? neededMin > 45
      : todayKm + 0.05 < neededKm;
  final kmText = _formatKm(todayKm);
  final message = exceeds
      ? _partialReturn(
          requiredRunKm: requiredRunKm,
          today: practice.activity.id == 'running'
              ? '${kmText}kmまでにします'
              : '${practice.activity.displayName}${kmText}kmまでにします',
        )
      : '今日やるなら${practice.activity.displayName}${kmText}km${todayKm + 0.05 < neededKm ? 'までにします' : 'にします'}。';
  return _ExercisePlan(
    message,
    activityId: practice.activity.id,
    amount: double.parse(kmText),
    unit: CoachExerciseUnit.kilometers,
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
  final neededMin = overageKcal / perMinute;
  var cap = 45.0;
  if (practice.longestMinutes > 0) {
    cap = math.min(cap, practice.longestMinutes * 1.5);
  }
  final speed = practice.paceKmh ?? practice.activity.referenceSpeedKmh;
  if (practice.longestKm > 0 && speed != null && speed > 0) {
    cap = math.min(cap, practice.longestKm * 1.5 / speed * 60);
  }
  final today = math.min(neededMin, cap);
  final shown = math.max(1, today.round());
  final message = neededMin > 45
      ? _partialReturn(
          requiredRunKm: requiredRunKm,
          today: '${practice.activity.displayName}$shown分までにします',
        )
      : '今日やるなら${practice.activity.displayName}$shown分${today + 0.05 < neededMin ? 'までにします' : 'にします'}。';
  final distanceWithoutSpeed =
      practice.activity.quantityUnit == ExerciseQuantityUnit.distanceKm &&
      (practice.activity.referenceSpeedKmh == null ||
          practice.activity.referenceSpeedKmh! <= 0);
  if (distanceWithoutSpeed || practice.met <= 1) {
    return _ExercisePlan(message);
  }
  return _ExercisePlan(
    message,
    activityId: practice.activity.id,
    amount: shown.toDouble(),
    unit: CoachExerciseUnit.minutes,
    met: practice.activity.quantityUnit == ExerciseQuantityUnit.durationMin
        ? practice.met
        : null,
  );
}

String _partialReturn({required double requiredRunKm, required String today}) {
  return '今日の超過を戻すには、ランニング${_formatKm(requiredRunKm)}kmが必要です。'
      '今日やるなら$today。'
      '残りは明日以降の食事で調整しましょう。';
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
