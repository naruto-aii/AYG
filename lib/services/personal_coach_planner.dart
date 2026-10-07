import 'dart:math' as math;

import '../data/coach_food_catalog.dart';
import '../utils/meal_slot.dart';

/// 残りkcalで決まる食事の区分。運動と「今日はここまで」は呼び出し側。
enum PersonalCoachBand { snack, light, standard, hearty }

/// 提案1件。量はカタログの選択肢だけ。
class PlannedCoachItem {
  const PlannedCoachItem({
    required this.foodCode,
    required this.displayName,
    required this.label,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.saltEqG,
    required this.role,
    required this.subrole,
    this.contentsNote,
  });

  final String foodCode;
  final String displayName;
  final String label;
  final int grams;
  final int kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final double saltEqG;
  final CoachFoodRole role;
  final CoachFoodSubrole subrole;
  final String? contentsNote;
}

class PlannedCoachMeal {
  const PlannedCoachMeal({
    required this.band,
    required this.items,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.saltEqG,
    required this.score,
    required this.headline,
  });

  final PersonalCoachBand band;
  final List<PlannedCoachItem> items;
  final int kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final double saltEqG;
  final double score;
  final String headline;
}

/// 22:00〜翌4:59。運動の提案だけが使う（夜は運動を勧めない）。
bool personalCoachIsNight(DateTime now) {
  return now.hour >= 22 || now.hour < 5;
}

/// 22:00〜23:59。その日の残りは寝る前の1回だけなので、軽食までにする。
///
/// 0:00〜4:59 は日付が変わった直後で、今日の食事はまだ全部これから。
/// ここを夜として間食だけにすると、目標がほぼ丸ごと残っていても
/// 牛乳や果物1品しか出なかった（2,438kcal 残りで間食だけ、の原因）。
bool personalCoachIsLateEvening(DateTime now) {
  return now.hour >= 22;
}

/// 22時以降の1回は軽食（450kcal未満）まで。残りが多くても夜遅くに一食分は出さない。
const double personalCoachLateEveningCapKcal = 449;

/// 1回の提案で埋める上限。22時以降は軽食まで。
double personalCoachEffectiveRemaining(double remainingKcal, DateTime? now) {
  if (now != null && personalCoachIsLateEvening(now)) {
    return math.min(remainingKcal, personalCoachLateEveningCapKcal);
  }
  return remainingKcal;
}

PersonalCoachBand? personalCoachMealBand(double remainingKcal, DateTime? now) {
  if (!remainingKcal.isFinite || remainingKcal < 50) {
    return null;
  }
  remainingKcal = personalCoachEffectiveRemaining(remainingKcal, now);
  if (remainingKcal < 250) {
    return PersonalCoachBand.snack;
  }
  if (remainingKcal < 450) {
    return PersonalCoachBand.light;
  }
  if (remainingKcal < 650) {
    return PersonalCoachBand.standard;
  }
  return PersonalCoachBand.hearty;
}

/// 上位 [limit] 案。候補が尽きるときは除外を外して出し直す。
List<PlannedCoachMeal> planPersonalCoachMeals({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  DateTime? now,
  int limit = 10,
}) {
  final band = personalCoachMealBand(remainingKcal, now);
  if (band == null || foods.isEmpty || limit <= 0) {
    return const [];
  }
  remainingKcal = personalCoachEffectiveRemaining(remainingKcal, now);
  final first = _search(
    foods: foods,
    excludedFoodCodes: excludedFoodCodes,
    remainingKcal: remainingKcal,
    band: band,
    limit: limit,
  );
  if (first.isNotEmpty || excludedFoodCodes.isEmpty) {
    return first;
  }
  return _search(
    foods: foods,
    excludedFoodCodes: const {},
    remainingKcal: remainingKcal,
    band: band,
    limit: limit,
  );
}

class _Bit {
  const _Bit({
    required this.stock,
    required this.portion,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.salt,
  });

  final CoachFoodStock stock;
  final CoachPortionOption portion;
  final int kcal;
  final double protein;
  final double fat;
  final double carb;
  final double salt;

  CoachFoodCandidate get food => stock.candidate;
  String get code => food.foodCode;
}

class _Ranked {
  _Ranked({
    required this.score,
    required this.key,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.salt,
    required this.items,
  });

  final double score;
  final String key;
  final int kcal;
  final double protein;
  final double fat;
  final double carb;
  final double salt;
  final List<_Bit> items;
}

List<PlannedCoachMeal> _search({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  required PersonalCoachBand band,
  required int limit,
}) {
  final usable = [
    for (final food in foods)
      if (_kept(food, excludedFoodCodes)) food,
  ];
  final tier = switch (band) {
    PersonalCoachBand.snack => CoachPortionTier.any,
    PersonalCoachBand.light => CoachPortionTier.light,
    PersonalCoachBand.standard => CoachPortionTier.standard,
    PersonalCoachBand.hearty => CoachPortionTier.hearty,
  };
  final bits = <_Bit>[
    for (final food in usable)
      for (final portion in food.candidate.portions)
        if (portion.tier == CoachPortionTier.any || portion.tier == tier)
          _bit(food, portion),
  ];
  final range = _targetRange(remainingKcal, band);
  final low = range.$1;
  final high = range.$2;
  final stapleCap = band == PersonalCoachBand.hearty ? 400 : 300;
  final mainCap = band == PersonalCoachBand.hearty ? 300 : 250;
  final saltCap = band == PersonalCoachBand.hearty ? 3.5 : 3.0;
  final ranked = <_Ranked>[];

  void offer(List<_Bit> items) {
    if (items.isEmpty) {
      return;
    }
    final codes = <String>{};
    var kcal = 0;
    var protein = 0.0;
    var fat = 0.0;
    var carb = 0.0;
    var salt = 0.0;
    var mainKcal = 0;
    var mainProtein = 0.0;
    var stapleCarb = 0.0;
    var meatFish = 0;
    var eggs = 0;
    var eggGrams = 0;
    var silk = false;
    var cotton = false;
    var starchy = 0;
    var green = 0;
    var tomato = false;
    var mini = false;
    var bread = false;
    var fish = false;
    var dairy = 0;
    var fruit = 0;
    var staple = 0;
    var main = 0;
    var side = 0;
    for (final item in items) {
      if (!codes.add(item.code)) {
        return;
      }
      kcal += item.kcal;
      protein += item.protein;
      fat += item.fat;
      carb += item.carb;
      salt += item.salt;
      switch (item.food.role) {
        case CoachFoodRole.staple:
          staple++;
          stapleCarb += item.carb;
          if (item.kcal >= stapleCap) {
            return;
          }
          bread = bread || item.food.isBreadOrNoodle;
        case CoachFoodRole.main:
          main++;
          mainKcal += item.kcal;
          mainProtein += item.protein;
          if (item.food.subrole == CoachFoodSubrole.meat ||
              item.food.subrole == CoachFoodSubrole.fish) {
            meatFish++;
          }
          if (item.food.subrole == CoachFoodSubrole.fish) {
            fish = true;
          }
          if (item.food.subrole == CoachFoodSubrole.egg) {
            eggs++;
            eggGrams += item.portion.grams;
          }
          if (item.code == '04033') {
            silk = true;
          }
          if (item.code == '04032') {
            cotton = true;
          }
        case CoachFoodRole.side:
          side++;
          if (item.kcal >= 150) {
            return;
          }
          if (item.food.isGreenYellowVegetable) {
            green++;
          }
          if (item.food.isStarchySide) {
            starchy++;
          }
          if (item.code == '06182') {
            tomato = true;
          }
          if (item.code == '06183') {
            mini = true;
          }
        case CoachFoodRole.dairy:
          dairy++;
          if (item.kcal >= 150) {
            return;
          }
        case CoachFoodRole.fruit:
          fruit++;
          if (item.kcal >= 100) {
            return;
          }
      }
    }
    if (kcal > remainingKcal || kcal < low || kcal > high) {
      return;
    }
    if (salt >= saltCap || mainKcal >= mainCap) {
      return;
    }
    if (meatFish > 1 || eggs > 1 || eggGrams > 100 || (silk && cotton)) {
      return;
    }
    if (starchy > 1 || (tomato && mini) || (bread && fish)) {
      return;
    }
    if (band == PersonalCoachBand.snack) {
      if (staple != 0 || main != 0 || side != 0) {
        return;
      }
      if (items.length == 2) {
        final yogurt =
            items.any(
              (item) => item.code == '13025' || item.code == '13053',
            ) &&
            fruit == 1 &&
            dairy == 1;
        if (!yogurt) {
          return;
        }
      } else if (items.length != 1 || (dairy + fruit) != 1) {
        return;
      }
    } else if (band == PersonalCoachBand.light) {
      if (staple != 1 || main != 1 || side > 1 || dairy + fruit + side > 1) {
        return;
      }
      if (mainProtein < 6) {
        return;
      }
      final mainItem = items.firstWhere(
        (item) => item.food.role == CoachFoodRole.main,
      );
      final meat =
          mainItem.food.subrole == CoachFoodSubrole.meat ||
          mainItem.food.subrole == CoachFoodSubrole.fish;
      if (meat && mainItem.portion.grams != 60) {
        return;
      }
    } else {
      if (staple != 1 || side != 2 || green < 1 || dairy + fruit > 1) {
        return;
      }
      if (main < 1 || main > 2 || mainProtein < 6) {
        return;
      }
      if (main == 1) {
        final only = items.firstWhere(
          (item) => item.food.role == CoachFoodRole.main,
        );
        final animal =
            only.food.subrole == CoachFoodSubrole.meat ||
            only.food.subrole == CoachFoodSubrole.fish;
        if (band == PersonalCoachBand.hearty) {
          if (!animal || only.portion.grams < 90 || only.portion.grams > 150) {
            return;
          }
        } else if (animal &&
            (only.portion.grams < 60 || only.portion.grams > 120)) {
          return;
        }
      }
      if (main == 2) {
        final mains = [
          for (final item in items)
            if (item.food.role == CoachFoodRole.main) item,
        ];
        final egg = mains.any(
          (item) => item.food.subrole == CoachFoodSubrole.egg,
        );
        final soy = mains.any(
          (item) => item.food.subrole == CoachFoodSubrole.soy,
        );
        final animal = mains.any(
          (item) =>
              item.food.subrole == CoachFoodSubrole.meat ||
              item.food.subrole == CoachFoodSubrole.fish,
        );
        if (animal) {
          if (band != PersonalCoachBand.hearty) {
            return;
          }
          final flesh = mains.firstWhere(
            (item) =>
                item.food.subrole == CoachFoodSubrole.meat ||
                item.food.subrole == CoachFoodSubrole.fish,
          );
          final extra = mains.firstWhere((item) => item != flesh);
          final allowed =
              (extra.code == '04033' && extra.portion.grams == 150) ||
              (extra.code == '04046' && extra.portion.grams == 50) ||
              (extra.code == '12005' && extra.portion.grams == 50);
          if (!allowed || flesh.portion.grams < 90 || flesh.portion.grams > 120) {
            return;
          }
        } else if (!(egg && soy)) {
          return;
        }
      }
    }

    final score = _score(
      band: band,
      low: low,
      high: high,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
      mainProtein: mainProtein,
      stapleCarb: stapleCarb,
      count: items.length,
    );
    final key = (items.map((item) => '${item.code}:${item.portion.grams}').toList()
          ..sort())
        .join(',');
    _insertRanked(
      ranked: ranked,
      limit: limit,
      score: score,
      key: key,
      kcal: kcal,
      protein: protein,
      fat: fat,
      carb: carb,
      salt: salt,
      items: items,
    );
  }

  final staples = [
    for (final bit in bits)
      if (bit.food.role == CoachFoodRole.staple && bit.kcal < stapleCap) bit,
  ];
  final mains = [
    for (final bit in bits)
      if (bit.food.role == CoachFoodRole.main) bit,
  ];
  final sides = [
    for (final bit in bits)
      if (bit.food.role == CoachFoodRole.side && bit.kcal < 150) bit,
  ];
  final dairies = [
    for (final bit in bits)
      if (bit.food.role == CoachFoodRole.dairy && bit.kcal < 150) bit,
  ];
  final fruits = [
    for (final bit in bits)
      if (bit.food.role == CoachFoodRole.fruit && bit.kcal < 100) bit,
  ];

  if (band == PersonalCoachBand.snack) {
    for (final item in [...dairies, ...fruits]) {
      offer([item]);
    }
    final yogurts = [
      for (final item in dairies)
        if (item.code == '13025' || item.code == '13053') item,
    ];
    for (final yogurt in yogurts) {
      for (final fruit in fruits) {
        offer([yogurt, fruit]);
      }
    }
  } else if (band == PersonalCoachBand.light) {
    final lightMains = [
      for (final item in mains)
        if (item.protein >= 6 &&
            item.kcal < mainCap &&
            (item.food.subrole == CoachFoodSubrole.egg ||
                item.food.subrole == CoachFoodSubrole.soy ||
                ((item.food.subrole == CoachFoodSubrole.meat ||
                        item.food.subrole == CoachFoodSubrole.fish) &&
                    item.portion.grams == 60)))
          item,
    ];
    final extras = <_Bit?>[null, ...sides, ...dairies, ...fruits];
    for (final staple in staples) {
      for (final main in lightMains) {
        if (staple.food.isBreadOrNoodle && main.food.isFish) {
          continue;
        }
        for (final extra in extras) {
          if (extra != null && extra.code == main.code) {
            continue;
          }
          offer([staple, main, ?extra]);
        }
      }
    }
  } else {
    final sidePairs = <( _Bit, _Bit)>[];
    for (var i = 0; i < sides.length; i++) {
      for (var j = i + 1; j < sides.length; j++) {
        final a = sides[i];
        final b = sides[j];
        if (a.code == b.code) {
          continue;
        }
        final green =
            a.food.isGreenYellowVegetable || b.food.isGreenYellowVegetable;
        final starchy =
            (a.food.isStarchySide ? 1 : 0) + (b.food.isStarchySide ? 1 : 0);
        final tomato = a.code == '06182' || b.code == '06182';
        final mini = a.code == '06183' || b.code == '06183';
        if (!green || starchy > 1 || (tomato && mini)) {
          continue;
        }
        sidePairs.add((a, b));
      }
    }
    final singleMains = <_Bit>[];
    for (final item in mains) {
      if (item.kcal >= mainCap || item.protein < 6) {
        continue;
      }
      final animal =
          item.food.subrole == CoachFoodSubrole.meat ||
          item.food.subrole == CoachFoodSubrole.fish;
      if (band == PersonalCoachBand.hearty) {
        if (animal && item.portion.grams >= 90 && item.portion.grams <= 150) {
          singleMains.add(item);
        }
        continue;
      }
      if (animal) {
        if (item.portion.grams >= 60 && item.portion.grams <= 120) {
          singleMains.add(item);
        }
        continue;
      }
      singleMains.add(item);
    }
    final pairs = <List<_Bit>>[];
    final eggs = [
      for (final item in mains)
        if (item.food.subrole == CoachFoodSubrole.egg) item,
    ];
    final soys = [
      for (final item in mains)
        if (item.food.subrole == CoachFoodSubrole.soy) item,
    ];
    for (final egg in eggs) {
      for (final soy in soys) {
        if (egg.kcal + soy.kcal >= mainCap) {
          continue;
        }
        if (egg.protein + soy.protein < 6) {
          continue;
        }
        if ((egg.code == '04033' && soy.code == '04032') ||
            (egg.code == '04032' && soy.code == '04033')) {
          continue;
        }
        pairs.add([egg, soy]);
      }
    }
    if (band == PersonalCoachBand.hearty) {
      const addons = <(String, int)>[
        ('04033', 150),
        ('04046', 50),
        ('12005', 50),
      ];
      for (final flesh in mains) {
        final animal =
            flesh.food.subrole == CoachFoodSubrole.meat ||
            flesh.food.subrole == CoachFoodSubrole.fish;
        if (!animal ||
            flesh.portion.grams < 90 ||
            flesh.portion.grams > 120) {
          continue;
        }
        for (final addon in addons) {
          _Bit? extra;
          for (final item in mains) {
            if (item.code == addon.$1 && item.portion.grams == addon.$2) {
              extra = item;
              break;
            }
          }
          if (extra == null || extra.code == flesh.code) {
            continue;
          }
          if (flesh.kcal + extra.kcal >= mainCap) {
            continue;
          }
          if (flesh.protein + extra.protein < 6) {
            continue;
          }
          pairs.add([flesh, extra]);
        }
      }
    }
    final extraBits = <_Bit>[...dairies, ...fruits];
    void emit(List<_Bit> mainItems, _Bit staple) {
      if (staple.food.isBreadOrNoodle &&
          mainItems.any((item) => item.food.isFish)) {
        return;
      }
      var mainKcal = 0;
      var mainProtein = 0.0;
      var mainFat = 0.0;
      var mainCarb = 0.0;
      var mainSalt = 0.0;
      for (final item in mainItems) {
        mainKcal += item.kcal;
        mainProtein += item.protein;
        mainFat += item.fat;
        mainCarb += item.carb;
        mainSalt += item.salt;
      }
      final baseKcal = staple.kcal + mainKcal;
      if (baseKcal > high) {
        return;
      }
      final baseProtein = staple.protein + mainProtein;
      final baseFat = staple.fat + mainFat;
      final baseCarb = staple.carb + mainCarb;
      final baseSalt = staple.salt + mainSalt;
      for (final pair in sidePairs) {
        final sidesKcal = pair.$1.kcal + pair.$2.kcal;
        final coreKcal = baseKcal + sidesKcal;
        if (coreKcal > high) {
          continue;
        }
        final coreProtein = baseProtein + pair.$1.protein + pair.$2.protein;
        final coreFat = baseFat + pair.$1.fat + pair.$2.fat;
        final coreCarb = baseCarb + pair.$1.carb + pair.$2.carb;
        final coreSalt = baseSalt + pair.$1.salt + pair.$2.salt;
        void maybe(
          int kcal,
          double protein,
          double fat,
          double carb,
          double salt,
          int count,
          List<_Bit> Function() build,
        ) {
          if (kcal > remainingKcal ||
              kcal < low ||
              kcal > high ||
              salt >= saltCap) {
            return;
          }
          final score = _score(
            band: band,
            low: low,
            high: high,
            kcal: kcal,
            protein: protein,
            fat: fat,
            carb: carb,
            mainProtein: mainProtein,
            stapleCarb: staple.carb,
            count: count,
          );
          if (ranked.length >= limit && score > ranked.last.score) {
            return;
          }
          _insertRanked(
            ranked: ranked,
            limit: limit,
            score: score,
            kcal: kcal,
            protein: protein,
            fat: fat,
            carb: carb,
            salt: salt,
            items: build(),
          );
        }

        maybe(
          coreKcal,
          coreProtein,
          coreFat,
          coreCarb,
          coreSalt,
          mainItems.length + 3,
          () => [staple, ...mainItems, pair.$1, pair.$2],
        );
        for (final extra in extraBits) {
          if (mainItems.any((item) => item.code == extra.code)) {
            continue;
          }
          final total = coreKcal + extra.kcal;
          if (total > high || total < low || total > remainingKcal) {
            continue;
          }
          maybe(
            total,
            coreProtein + extra.protein,
            coreFat + extra.fat,
            coreCarb + extra.carb,
            coreSalt + extra.salt,
            mainItems.length + 4,
            () => [staple, ...mainItems, pair.$1, pair.$2, extra],
          );
        }
      }
    }

    for (final staple in staples) {
      for (final main in singleMains) {
        emit([main], staple);
      }
      for (final pair in pairs) {
        emit(pair, staple);
      }
    }
  }

  return [
    for (final row in ranked)
      PlannedCoachMeal(
        band: band,
        items: [for (final item in row.items) _item(item)],
        kcal: row.kcal,
        proteinG: row.protein,
        fatG: row.fat,
        carbG: row.carb,
        saltEqG: row.salt,
        score: row.score,
        headline: row.items.map(_phrase).join('、'),
      ),
  ];
}

void _insertRanked({
  required List<_Ranked> ranked,
  required int limit,
  required double score,
  String? key,
  required int kcal,
  required double protein,
  required double fat,
  required double carb,
  required double salt,
  required List<_Bit> items,
}) {
  final resolved =
      key ??
      (items.map((item) => '${item.code}:${item.portion.grams}').toList()
            ..sort())
          .join(',');
  if (ranked.length >= limit && score > ranked.last.score) {
    return;
  }
  final existing = ranked.indexWhere((row) => row.key == resolved);
  if (existing >= 0) {
    if (score >= ranked[existing].score) {
      return;
    }
    ranked.removeAt(existing);
  }
  final row = _Ranked(
    score: score,
    key: resolved,
    kcal: kcal,
    protein: protein,
    fat: fat,
    carb: carb,
    salt: salt,
    items: items,
  );
  var placed = false;
  for (var i = 0; i < ranked.length; i++) {
    if (score < ranked[i].score ||
        (score == ranked[i].score && resolved.compareTo(ranked[i].key) < 0)) {
      ranked.insert(i, row);
      placed = true;
      break;
    }
  }
  if (!placed) {
    ranked.add(row);
  }
  if (ranked.length > limit) {
    ranked.removeLast();
  }
}

bool _kept(CoachFoodStock food, Set<String> excluded) {
  if (!excluded.contains(food.candidate.foodCode)) {
    return true;
  }
  final role = food.candidate.role;
  return role != CoachFoodRole.main &&
      role != CoachFoodRole.side &&
      role != CoachFoodRole.fruit;
}

_Bit _bit(CoachFoodStock stock, CoachPortionOption portion) {
  return _Bit(
    stock: stock,
    portion: portion,
    kcal: _roundKcal(stock.kcalFor(portion.grams)),
    protein: stock.proteinFor(portion.grams),
    fat: stock.fatFor(portion.grams),
    carb: stock.carbFor(portion.grams),
    salt: stock.saltFor(portion.grams),
  );
}

int _roundKcal(double value) {
  if (!value.isFinite) {
    return 0;
  }
  return (value + 1e-9).round();
}

(double, double) _targetRange(double remaining, PersonalCoachBand band) {
  switch (band) {
    case PersonalCoachBand.snack:
      final cap = math.min(remaining, 200).toDouble();
      return (cap * 0.7, cap);
    case PersonalCoachBand.light:
    case PersonalCoachBand.standard:
      return (remaining * 0.8, remaining);
    case PersonalCoachBand.hearty:
      final cap = math.min(remaining, 850).toDouble();
      return (cap * 0.8, cap);
  }
}

double _score({
  required PersonalCoachBand band,
  required double low,
  required double high,
  required int kcal,
  required double protein,
  required double fat,
  required double carb,
  required double mainProtein,
  required double stapleCarb,
  required int count,
}) {
  final mid = (low + high) / 2;
  var score = (kcal - mid).abs() / (high == 0 ? 1 : high);
  if (band != PersonalCoachBand.snack) {
    final proteinKcal = protein * 4;
    final fatKcal = fat * 9;
    final carbKcal = carb * 4;
    final total = proteinKcal + fatKcal + carbKcal;
    if (total > 0) {
      final points =
          _outside(proteinKcal / total * 100, 13, 20) +
          _outside(fatKcal / total * 100, 20, 30) +
          _outside(carbKcal / total * 100, 50, 65);
      score += points / 10;
    }
    if (band == PersonalCoachBand.hearty) {
      score += _outside(mainProtein, 17, 28) / 10;
      score += _outside(stapleCarb, 70, 95) / 20;
    } else {
      score += _outside(mainProtein, 10, 17) / 10;
      if (band == PersonalCoachBand.standard) {
        score += _outside(stapleCarb, 40, 70) / 20;
      }
    }
  }
  score += count * (band == PersonalCoachBand.snack ? 0.02 : 0.005);
  return score;
}

double _outside(double value, double low, double high) {
  if (value < low) {
    return low - value;
  }
  if (value > high) {
    return value - high;
  }
  return 0;
}

PlannedCoachItem _item(_Bit bit) {
  return PlannedCoachItem(
    foodCode: bit.code,
    displayName: bit.food.displayName,
    label: bit.portion.label,
    grams: bit.portion.grams,
    kcal: bit.kcal,
    proteinG: bit.protein,
    fatG: bit.fat,
    carbG: bit.carb,
    saltEqG: bit.salt,
    role: bit.food.role,
    subrole: bit.food.subrole,
    contentsNote: bit.food.contentsNote,
  );
}

String _phrase(_Bit bit) {
  final note = bit.food.contentsNote;
  final text = '${bit.food.displayName} ${bit.portion.label}';
  if (note == null || note.isEmpty) {
    return text;
  }
  return '$text（$note）';
}

String personalCoachBandLabel(PersonalCoachBand band) {
  return switch (band) {
    PersonalCoachBand.snack => '間食',
    PersonalCoachBand.light => '軽食',
    PersonalCoachBand.standard => '一食（ちゃんと）',
    PersonalCoachBand.hearty => '一食（しっかり）',
  };
}

// ---------------------------------------------------------------------------
// 1日の残りを、これからの食事に分ける。
//
// 根拠:
// - 1食は「主食＋主菜＋副菜」で 450〜850kcal（スマートミール基準、厚生労働省
//   「生活習慣病予防その他の健康増進を目的として提供する食事の目安」2015）。
//   650kcal 未満が「ちゃんと」、650〜850kcal が「しっかり」。1食の上限は 850kcal。
// - 主食・主菜・副菜をそろえた食事を1日2回以上（第4次食育推進基本計画）。
// - 牛乳・乳製品と果物は1日それぞれ2つ（SV）が目安（食事バランスガイド、
//   厚生労働省・農林水産省）。間食はこの範囲で、食事のあとの端数だけを埋める。
// ---------------------------------------------------------------------------

/// 1食の下限（スマートミール「ちゃんと」の下限）。
const double personalCoachMealFloorKcal = 450;

/// 1食の上限（スマートミール「しっかり」の上限）。
const double personalCoachMealCapKcal = 850;

/// 食事のあとに足す間食の数の上限（乳製品と果物、各2つ/日の範囲）。
const int personalCoachSnackLimit = 2;

/// 間食1回の上限。
const double personalCoachSnackCapKcal = 200;

/// 今の時刻から、今日これからの食事の枠。
///
/// 0:00〜10:59 は朝・昼・夕。日付が変わった直後（0〜4時）は、今日の3食の予定として出す。
/// 11:00〜14:59 は昼・夕。15:00〜21:59 は夕。22時以降は枠なし（軽食1回だけ）。
List<MealSlot> personalCoachRemainingSlots(DateTime now) {
  final hour = now.hour;
  if (hour < 11) {
    return const [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner];
  }
  if (hour < 15) {
    return const [MealSlot.lunch, MealSlot.dinner];
  }
  if (hour < 22) {
    return const [MealSlot.dinner];
  }
  return const [];
}

/// 1日の案の中の1回分。[budgetKcal] はこの回に割り当てた kcal。
class PlannedCoachDayMeal {
  const PlannedCoachDayMeal({
    required this.slot,
    required this.label,
    required this.budgetKcal,
    required this.meal,
  });

  final MealSlot slot;

  /// 「朝食」「昼食」「夕食」「間食」、22時以降は「軽食」。
  final String label;
  final double budgetKcal;
  final PlannedCoachMeal meal;
}

class PlannedCoachDay {
  const PlannedCoachDay({
    required this.meals,
    required this.kcal,
    required this.remainingKcal,
  });

  final List<PlannedCoachDayMeal> meals;
  final int kcal;
  final double remainingKcal;

  /// 案を全部食べても残る kcal。
  double get leftoverKcal => math.max(0, remainingKcal - kcal);
}

/// 残り [remainingKcal] を、今日これからの食事（主食＋主菜＋副菜）に分けた案を
/// 最大 [limit] 通り返す。食事のあとの端数だけを間食で埋める。
///
/// - 食事の回数は、これからの枠の数と「1食 450kcal 以上」で決める。
/// - 1食は 850kcal まで。残りを回数で割り、その回の上限にする。
/// - 同じ日の案の中では、主菜・副菜・果物を食事ごとに変える。
List<PlannedCoachDay> planPersonalCoachDay({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  required DateTime now,
  int limit = 5,
}) {
  if (!remainingKcal.isFinite || remainingKcal < 50 || foods.isEmpty) {
    return const [];
  }
  if (limit <= 0) {
    return const [];
  }
  final slots = personalCoachRemainingSlots(now);
  if (slots.isEmpty || remainingKcal < personalCoachMealFloorKcal) {
    return _singleMealDays(
      foods: foods,
      excludedFoodCodes: excludedFoodCodes,
      remainingKcal: remainingKcal,
      now: now,
      limit: limit,
      slot: slots.isEmpty ? MealSlot.snack : slots.first,
    );
  }
  final count = math.max(
    1,
    math.min(slots.length, (remainingKcal / personalCoachMealFloorKcal).floor()),
  );
  final chosen = _pickSlots(slots, count);
  // どの回も同じ上限にする。残りを回数で割り、1食 850kcal で止める。
  final budget = math.min(remainingKcal / chosen.length, personalCoachMealCapKcal);
  final band = personalCoachMealBand(budget, null);
  if (band == null) {
    return const [];
  }
  final pool = limit * chosen.length * 4;
  var ranked = _search(
    foods: foods,
    excludedFoodCodes: excludedFoodCodes,
    remainingKcal: budget,
    band: band,
    limit: pool,
  );
  if (ranked.isEmpty && excludedFoodCodes.isNotEmpty) {
    ranked = _search(
      foods: foods,
      excludedFoodCodes: const {},
      remainingKcal: budget,
      band: band,
      limit: pool,
    );
  }
  if (ranked.isEmpty) {
    return const [];
  }
  final days = <PlannedCoachDay>[];
  final seen = <String>{};
  for (var variant = 0; variant < limit; variant++) {
    final day = _buildDay(
      foods: foods,
      excludedFoodCodes: excludedFoodCodes,
      remainingKcal: remainingKcal,
      slots: chosen,
      budget: budget,
      ranked: ranked,
      variant: variant,
    );
    final key = day.meals
        .map(
          (meal) => meal.meal.items
              .map((item) => '${item.foodCode}:${item.grams}')
              .join(','),
        )
        .join('|');
    if (seen.add(key)) {
      days.add(day);
    }
  }
  return days;
}

/// 先頭（今これから）と最後（夕食）を残す。
List<MealSlot> _pickSlots(List<MealSlot> slots, int count) {
  if (count >= slots.length) {
    return slots;
  }
  if (count == 1) {
    return [slots.first];
  }
  return [slots.first, slots.last];
}

List<PlannedCoachDay> _singleMealDays({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  required DateTime now,
  required int limit,
  required MealSlot slot,
}) {
  final meals = planPersonalCoachMeals(
    foods: foods,
    excludedFoodCodes: excludedFoodCodes,
    remainingKcal: remainingKcal,
    now: now,
    limit: limit,
  );
  final budget = personalCoachEffectiveRemaining(remainingKcal, now);
  return [
    for (final meal in meals)
      PlannedCoachDay(
        meals: [
          PlannedCoachDayMeal(
            slot: slot,
            label: _labelFor(slot, meal.band),
            budgetKcal: budget,
            meal: meal,
          ),
        ],
        kcal: meal.kcal,
        remainingKcal: remainingKcal,
      ),
  ];
}

String _labelFor(MealSlot slot, PersonalCoachBand band) {
  if (band == PersonalCoachBand.snack) {
    return MealSlot.snack.label;
  }
  if (slot == MealSlot.snack) {
    return personalCoachBandLabel(band);
  }
  return slot.label;
}

/// 同じ日の中で主菜・副菜・果物が重ならないものを、[variant] ずらして選ぶ。
PlannedCoachDay _buildDay({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  required List<MealSlot> slots,
  required double budget,
  required List<PlannedCoachMeal> ranked,
  required int variant,
}) {
  final used = <String>{...excludedFoodCodes};
  final meals = <PlannedCoachDayMeal>[];
  var planned = 0;
  for (var index = 0; index < slots.length; index++) {
    final start = (variant * slots.length + index) % ranked.length;
    var meal = ranked[start];
    for (var step = 0; step < ranked.length; step++) {
      final candidate = ranked[(start + step) % ranked.length];
      final clash = candidate.items.any(
        (item) => _variedRole(item.role) && used.contains(item.foodCode),
      );
      if (!clash) {
        meal = candidate;
        break;
      }
    }
    meals.add(
      PlannedCoachDayMeal(
        slot: slots[index],
        label: slots[index].label,
        budgetKcal: budget,
        meal: meal,
      ),
    );
    planned += meal.kcal;
    for (final item in meal.items) {
      if (_variedRole(item.role)) {
        used.add(item.foodCode);
      }
    }
  }
  for (var snack = 0; snack < personalCoachSnackLimit; snack++) {
    final left = remainingKcal - planned;
    if (left < 100) {
      break;
    }
    final snackBudget = math.min(left, personalCoachSnackCapKcal);
    final picked = _pickVariant(
      foods: foods,
      excludedFoodCodes: used,
      remainingKcal: snackBudget,
      variant: variant + snack,
      band: PersonalCoachBand.snack,
    );
    if (picked == null) {
      break;
    }
    meals.add(
      PlannedCoachDayMeal(
        slot: MealSlot.snack,
        label: MealSlot.snack.label,
        budgetKcal: snackBudget,
        meal: picked,
      ),
    );
    planned += picked.kcal;
    for (final item in picked.items) {
      used.add(item.foodCode);
    }
  }
  return PlannedCoachDay(
    meals: meals,
    kcal: planned,
    remainingKcal: remainingKcal,
  );
}

bool _variedRole(CoachFoodRole role) {
  return role == CoachFoodRole.main ||
      role == CoachFoodRole.side ||
      role == CoachFoodRole.fruit;
}

PlannedCoachMeal? _pickVariant({
  required List<CoachFoodStock> foods,
  required Set<String> excludedFoodCodes,
  required double remainingKcal,
  required int variant,
  PersonalCoachBand? band,
}) {
  final resolved = band ?? personalCoachMealBand(remainingKcal, null);
  if (resolved == null) {
    return null;
  }
  final want = variant + 1;
  var ranked = _search(
    foods: foods,
    excludedFoodCodes: excludedFoodCodes,
    remainingKcal: remainingKcal,
    band: resolved,
    limit: want,
  );
  if (ranked.isEmpty) {
    ranked = _search(
      foods: foods,
      excludedFoodCodes: const {},
      remainingKcal: remainingKcal,
      band: resolved,
      limit: want,
    );
  }
  if (ranked.isEmpty) {
    return null;
  }
  return ranked[variant % ranked.length];
}
