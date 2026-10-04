import 'dart:math' as math;

import '../data/coach_food_catalog.dart';
import '../data/met_activity_catalog.dart';
import '../models/exercise_entry.dart';
import '../models/exercise_quantity_unit.dart';
import '../services/exercise_calorie_calculator.dart';
import '../utils/local_date.dart';

/// ホームのコーチ画面に必ず出す注記。
const coachTrialNotice =
    'この提案は検証中です。食品の種類や量が偏ることがあります。気になった点はアプリ内の問い合わせから送ってください。次の版の改善に使います。';

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

/// 超過を戻す運動。超過が無い日は null。
///
/// 今すぐの量は、その種目の直近30日で一番長い記録の1.5倍まで、かつ45分以内。
/// やったことが無い人は、歩くか軽い自重で20分まで。
/// 体重が無い日は距離を出さない。
String? buildCoachExerciseMessage({
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
    return _distanceMessage(
      practice: practice,
      overageKcal: overageKcal,
      weightKg: weight,
      requiredRunKm: requiredRunKm,
      factor: factor,
    );
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

String _withoutWeight(_Practice? practice) {
  const head = '体重がないため、距離は出していません。';
  if (practice == null || practice.longestMinutes <= 0) {
    return '$head今日やるなら、歩くか軽い自重で20分までにします。';
  }
  final cap = math.min(45.0, practice.longestMinutes * 1.5);
  final minutes = math.max(1, cap.round());
  return '$head今日やるなら${practice.activity.displayName}$minutes分までにします。';
}

String _noviceMessage({
  required double overageKcal,
  required double weightKg,
  required double requiredRunKm,
}) {
  final walk = MetActivityCatalog.findById('walk_brisk');
  final speed = walk?.referenceSpeedKmh;
  final factor = walk?.netKcalPerKgKm;
  if (walk == null || speed == null || speed <= 0 || factor == null) {
    return '今日やるなら、歩くか軽い自重で20分までにします。';
  }
  final neededKm = overageKcal / (factor * weightKg);
  final neededMin = neededKm / speed * 60;
  final today = math.min(20.0, neededMin);
  final shown = math.max(1, today.round());
  if (neededMin > 45) {
    return _partialReturn(
      requiredRunKm: requiredRunKm,
      today: '、歩くか軽い自重で20分までにします',
    );
  }
  final capped = today + 0.05 < neededMin;
  final verb = capped ? 'までにします' : 'にします';
  return '今日やるなら、歩くか軽い自重で$shown分$verb。';
}

String? _distanceMessage({
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
  if (exceeds) {
    final today = practice.activity.id == 'running'
        ? '${kmText}kmまでにします'
        : '${practice.activity.displayName}${kmText}kmまでにします';
    return _partialReturn(requiredRunKm: requiredRunKm, today: today);
  }
  final capped = todayKm + 0.05 < neededKm;
  final verb = capped ? 'までにします' : 'にします';
  return '今日やるなら${practice.activity.displayName}${kmText}km$verb。';
}

String? _durationMessage({
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
  if (neededMin > 45) {
    return _partialReturn(
      requiredRunKm: requiredRunKm,
      today: '${practice.activity.displayName}$shown分までにします',
    );
  }
  final capped = today + 0.05 < neededMin;
  final verb = capped ? 'までにします' : 'にします';
  return '今日やるなら${practice.activity.displayName}$shown分$verb。';
}

String _partialReturn({required double requiredRunKm, required String today}) {
  return '今日の超過を戻すには、ランニング${_formatKm(requiredRunKm)}kmが必要です。'
      '今日やるなら$today。'
      '残りは明日以降の食事で調整しましょう。';
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
