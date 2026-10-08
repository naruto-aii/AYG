import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

/// 提案ロジックとは別に、B1〜B4 を書き直した検証。
/// daily_coach も personal_coach_planner も import しない。
class CoachRuleItem {
  const CoachRuleItem({required this.foodCode, required this.grams});

  final String foodCode;
  final int grams;
}

class _Food {
  const _Food({
    required this.code,
    required this.role,
    required this.subrole,
    required this.green,
    required this.starchy,
    required this.bread,
    required this.portions,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.salt,
  });

  final String code;
  final String role;
  final String subrole;
  final bool green;
  final bool starchy;
  final bool bread;
  final List<(String, int)> portions;
  final double kcal;
  final double protein;
  final double fat;
  final double carb;
  final double salt;
}

class PersonalCoachRules {
  static const nutrition = <String, List<double>>{
    '01088': [156, 2.5, 0.3, 37.1, 0.0],
    '01085': [152, 2.8, 1.0, 35.6, 0.0],
    '01111': [170, 2.7, 0.3, 39.4, 0.5],
    '01026': [248, 8.9, 4.1, 46.4, 1.2],
    '01034': [309, 10.1, 9.0, 48.6, 1.2],
    '01039': [95, 2.6, 0.4, 21.6, 0.3],
    '01128': [130, 4.8, 1.0, 26.0, 0.0],
    '11288': [177, 38.8, 3.3, 0.1, 0.2],
    '11225': [145, 25.5, 5.7, 0.0, 0.2],
    '11222': [220, 26.3, 13.9, 0.0, 0.2],
    '11229': [121, 29.6, 1.0, 0.0, 0.1],
    '11132': [186, 30.2, 7.6, 0.3, 0.1],
    '11124': [310, 26.7, 22.7, 0.3, 0.1],
    '11278': [202, 39.3, 5.9, 0.4, 0.2],
    '11270': [205, 28.0, 14.1, 0.4, 0.1],
    '10136': [160, 29.1, 5.1, 0.1, 0.2],
    '10005': [157, 25.9, 6.4, 0.1, 0.4],
    '10156': [264, 25.2, 22.4, 0.4, 0.3],
    '10174': [281, 23.3, 22.8, 0.2, 0.3],
    '10242': [260, 26.2, 20.4, 0.3, 0.1],
    '10206': [103, 25.2, 0.2, 0.2, 0.4],
    '10412': [179, 23.1, 10.9, 0.2, 2.0],
    '10253': [115, 26.4, 1.4, 0.1, 0.1],
    '12005': [134, 12.5, 10.4, 0.3, 0.3],
    '12021': [205, 14.8, 17.6, 0.3, 0.5],
    '12018': [146, 10.5, 9.2, 6.5, 1.2],
    '04033': [56, 5.3, 3.5, 2.0, 0.0],
    '04032': [73, 7.0, 4.9, 1.5, 0.0],
    '04046': [184, 16.5, 10.0, 12.1, 0.0],
    '06268': [23, 2.6, 0.5, 4.0, 0.0],
    '06264': [30, 3.9, 0.4, 5.2, 0.0],
    '06087': [14, 1.6, 0.1, 3.0, 0.0],
    '06061': [23, 1.2, 0.1, 5.2, 0.0],
    '06182': [20, 0.7, 0.1, 4.7, 0.0],
    '06183': [30, 1.1, 0.1, 7.2, 0.0],
    '06065': [13, 1.0, 0.1, 3.0, 0.0],
    '06312': [11, 0.6, 0.1, 2.8, 0.0],
    '06292': [12, 1.6, 0.0, 2.3, 0.0],
    '06215': [28, 0.7, 0.1, 8.5, 0.1],
    '06049': [80, 1.6, 0.3, 21.3, 0.0],
    '06016': [118, 11.5, 6.1, 8.9, 0.0],
    '06134': [15, 0.4, 0.1, 4.1, 0.0],
    '06100': [25, 2.7, 0.5, 4.5, 0.1],
    '06176': [95, 3.5, 1.7, 18.6, 0.0],
    '08017': [22, 2.7, 0.2, 5.2, 0.0],
    '08049': [41, 4.2, 0.5, 9.1, 0.0],
    '02018': [76, 1.9, 0.3, 18.1, 0.0],
    '02007': [131, 1.2, 0.2, 31.9, 0.0],
    '06192': [17, 1.0, 0.1, 4.5, 0.0],
    '13003': [61, 3.3, 3.8, 4.8, 0.1],
    '13005': [42, 3.8, 1.0, 5.5, 0.2],
    '13025': [56, 3.6, 3.0, 4.9, 0.1],
    '13053': [40, 3.7, 1.0, 5.2, 0.1],
    '13040': [313, 22.7, 26.0, 1.3, 2.8],
    '07176': [56, 0.2, 0.3, 16.2, 0.0],
    '07107': [93, 1.1, 0.2, 22.5, 0.0],
    '07029': [49, 0.7, 0.1, 11.5, 0.0],
    '07012': [31, 0.9, 0.1, 8.5, 0.0],
    '07054': [51, 1.0, 0.2, 13.4, 0.0],
    '07116': [58, 0.4, 0.1, 15.7, 0.0],
    '07088': [38, 0.3, 0.1, 11.3, 0.0],
    '07049': [63, 0.4, 0.2, 15.9, 0.0],
    '07097': [54, 0.6, 0.1, 13.7, 0.0],
    '07062': [40, 0.9, 0.1, 9.6, 0.0],
    '07136': [38, 0.6, 0.1, 10.2, 0.0],
    '07077': [41, 0.6, 0.1, 9.5, 0.0],
  };

  static final Map<String, _Food> _foods = _load();

  static Map<String, _Food> _load() {
    final sql = File(
      'supabase/migrations/20261007074302_personal_coach_food_roles.sql',
    ).readAsStringSync();
    final pattern = RegExp(
      r"\('(\d{5})', '[^']*', '[^']*', \d+, (?:null|'[^']*'), \d+, '(staple|main|side|dairy|fruit)', '([a-z]+)', (true|false), (true|false), (true|false),\s+'(\[.*?\])'::jsonb",
      dotAll: true,
    );
    final loaded = <String, _Food>{};
    for (final match in pattern.allMatches(sql)) {
      final code = match.group(1)!;
      final values = nutrition[code];
      if (values == null) {
        continue;
      }
      final raw = jsonDecode(match.group(7)!) as List<dynamic>;
      loaded[code] = _Food(
        code: code,
        role: match.group(2)!,
        subrole: match.group(3)!,
        green: match.group(4) == 'true',
        starchy: match.group(5) == 'true',
        bread: match.group(6) == 'true',
        portions: [
          for (final item in raw)
            if (item is Map)
              (
                item['tier'].toString(),
                (item['grams'] as num).toInt(),
              ),
        ],
        kcal: values[0],
        protein: values[1],
        fat: values[2],
        carb: values[3],
        salt: values[4],
      );
    }
    return loaded;
  }

  /// 空なら規則を満たす。1件でもあれば違反。
  static List<String> validate({
    required double remainingKcal,
    required bool night,
    required List<CoachRuleItem> items,
  }) {
    final problems = <String>[];
    if (items.isEmpty) {
      return ['空の案'];
    }
    // 22時以降は間食（200kcal）まで。
    if (night && remainingKcal.isFinite) {
      remainingKcal = math.min(remainingKcal, 200);
    }
    final band = _band(remainingKcal);
    if (band == null) {
      return ['食事を出さない区分なのに案がある'];
    }
    final seen = <String>{};
    final parsed = <_Scaled>[];
    for (final item in items) {
      final food = _foods[item.foodCode];
      if (food == null) {
        problems.add('候補外 ${item.foodCode}');
        continue;
      }
      if (!seen.add(item.foodCode)) {
        problems.add('同じ食品 ${item.foodCode}');
      }
      if (!_allowedGrams(food, band, item.grams)) {
        problems.add('選択肢にない量 ${item.foodCode} ${item.grams}g');
      }
      parsed.add(_scale(food, item.grams));
    }
    if (parsed.length != items.length) {
      return problems;
    }
    final lowHigh = _range(remainingKcal, band);
    final total = parsed.fold<int>(0, (sum, item) => sum + item.kcal);
    if (total > remainingKcal || total < lowHigh.$1 || total > lowHigh.$2) {
      problems.add('kcal $total が範囲外');
    }
    final salt = parsed.fold<double>(0, (sum, item) => sum + item.salt);
    final saltCap = band == 'hearty' ? 3.5 : 3.0;
    if (band != 'snack' && salt >= saltCap) {
      problems.add('食塩 $salt');
    }
    final staples = parsed.where((item) => item.food.role == 'staple').toList();
    final mains = parsed.where((item) => item.food.role == 'main').toList();
    final sides = parsed.where((item) => item.food.role == 'side').toList();
    final dairies = parsed.where((item) => item.food.role == 'dairy').toList();
    final fruits = parsed.where((item) => item.food.role == 'fruit').toList();
    final stapleCap = band == 'hearty' ? 400 : 300;
    final mainCap = band == 'hearty' ? 300 : 250;
    for (final staple in staples) {
      if (staple.kcal >= stapleCap) {
        problems.add('主食kcal ${staple.food.code}');
      }
    }
    final mainKcal = mains.fold<int>(0, (sum, item) => sum + item.kcal);
    final mainProtein = mains.fold<double>(0, (sum, item) => sum + item.protein);
    if (mains.isNotEmpty && (mainKcal >= mainCap || mainProtein < 6)) {
      problems.add('主菜の上限 ${mainKcal}kcal ${mainProtein}g');
    }
    for (final side in sides) {
      if (side.kcal >= 150) {
        problems.add('副菜kcal ${side.food.code}');
      }
    }
    for (final dairy in dairies) {
      if (dairy.kcal >= 150) {
        problems.add('乳製品kcal ${dairy.food.code}');
      }
    }
    for (final fruit in fruits) {
      if (fruit.kcal >= 100) {
        problems.add('果物kcal ${fruit.food.code}');
      }
    }
    final meatFish = mains.where(
      (item) => item.food.subrole == 'meat' || item.food.subrole == 'fish',
    );
    if (meatFish.length > 1) {
      problems.add('肉・魚が2品');
    }
    final eggs = mains.where((item) => item.food.subrole == 'egg').toList();
    final eggGrams = eggs.fold<int>(0, (sum, item) => sum + item.grams);
    if (eggs.length > 1 || eggGrams > 100) {
      problems.add('卵が多すぎる');
    }
    final silk = mains.any((item) => item.food.code == '04033');
    final cotton = mains.any((item) => item.food.code == '04032');
    if (silk && cotton) {
      problems.add('木綿と絹ごし');
    }
    if (sides.where((item) => item.food.starchy).length > 1) {
      problems.add('いも類が2品');
    }
    final tomato = sides.any((item) => item.food.code == '06182');
    final mini = sides.any((item) => item.food.code == '06183');
    if (tomato && mini) {
      problems.add('トマトとミニトマト');
    }
    if (staples.any((item) => item.food.bread) &&
        mains.any((item) => item.food.subrole == 'fish')) {
      problems.add('パン・麺と魚');
    }
    if (band == 'snack') {
      if (staples.isNotEmpty || mains.isNotEmpty || sides.isNotEmpty) {
        problems.add('間食に食事');
      }
      if (items.length == 2) {
        final yogurt = dairies.any(
          (item) => item.food.code == '13025' || item.food.code == '13053',
        );
        if (!(yogurt && fruits.length == 1 && dairies.length == 1)) {
          problems.add('間食の2品');
        }
      } else if (items.length != 1 || dairies.length + fruits.length != 1) {
        problems.add('間食の品数');
      }
    } else if (band == 'light') {
      if (staples.length != 1 || mains.length != 1) {
        problems.add('軽食の主食主菜');
      }
      if (sides.length + dairies.length + fruits.length > 1) {
        problems.add('軽食の付け合わせ');
      }
      if (meatFish.isNotEmpty && meatFish.single.grams != 60) {
        problems.add('軽食の肉・魚');
      }
    } else {
      if (staples.length != 1 || sides.length != 2) {
        problems.add('一食の品数');
      }
      if (!sides.any((item) => item.food.green)) {
        problems.add('緑黄色野菜がない');
      }
      if (dairies.length + fruits.length > 1) {
        problems.add('乳製品と果物');
      }
      if (mains.isEmpty || mains.length > 2) {
        problems.add('主菜の数');
      }
      if (mains.length == 1) {
        final only = mains.single;
        final animal = only.food.subrole == 'meat' || only.food.subrole == 'fish';
        if (band == 'hearty') {
          if (!animal || only.grams < 90 || only.grams > 150) {
            problems.add('しっかりの主菜');
          }
        } else if (animal && (only.grams < 60 || only.grams > 120)) {
          problems.add('ちゃんとの肉・魚');
        }
      }
      if (mains.length == 2) {
        final animal = mains.where(
          (item) => item.food.subrole == 'meat' || item.food.subrole == 'fish',
        );
        final egg = mains.any((item) => item.food.subrole == 'egg');
        final soy = mains.any((item) => item.food.subrole == 'soy');
        if (animal.isNotEmpty) {
          if (band != 'hearty') {
            problems.add('ちゃんとに主菜2品');
          }
          final flesh = animal.single;
          final extra = mains.firstWhere((item) => item != flesh);
          final allowed =
              (extra.food.code == '04033' && extra.grams == 150) ||
              (extra.food.code == '04046' && extra.grams == 50) ||
              (extra.food.code == '12005' && extra.grams == 50);
          if (!allowed || flesh.grams < 90 || flesh.grams > 120) {
            problems.add('しっかりの足し');
          }
        } else if (!(egg && soy)) {
          problems.add('卵と大豆以外の主菜2品');
        }
      }
    }
    for (final item in meatFish) {
      if (band == 'light' && item.grams != 60) {
        problems.add('肉・魚の量');
      }
      if (band == 'standard' && (item.grams < 60 || item.grams > 120)) {
        problems.add('肉・魚の量');
      }
      if (band == 'hearty' && (item.grams < 90 || item.grams > 150)) {
        problems.add('肉・魚の量');
      }
    }
    return problems;
  }

  static String? _band(double remaining) {
    if (!remaining.isFinite || remaining < 50) {
      return null;
    }
    if (remaining < 250) {
      return 'snack';
    }
    if (remaining < 450) {
      return 'light';
    }
    if (remaining < 650) {
      return 'standard';
    }
    return 'hearty';
  }

  static (double, double) _range(double remaining, String band) {
    switch (band) {
      case 'snack':
        final cap = math.min(remaining, 200).toDouble();
        return (cap * 0.7, cap);
      case 'light':
      case 'standard':
        return (remaining * 0.8, remaining);
      default:
        final cap = math.min(remaining, 850).toDouble();
        return (cap * 0.8, cap);
    }
  }

  static bool _allowedGrams(_Food food, String band, int grams) {
    final tier = switch (band) {
      'light' => 'light',
      'standard' => 'standard',
      'hearty' => 'hearty',
      _ => 'any',
    };
    return food.portions.any(
      (portion) =>
          portion.$2 == grams && (portion.$1 == 'any' || portion.$1 == tier),
    );
  }
}

class _Scaled {
  const _Scaled({
    required this.food,
    required this.grams,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carb,
    required this.salt,
  });

  final _Food food;
  final int grams;
  final int kcal;
  final double protein;
  final double fat;
  final double carb;
  final double salt;
}

_Scaled _scale(_Food food, int grams) {
  double amount(double per100) => per100 * grams / 100;
  final kcal = amount(food.kcal);
  return _Scaled(
    food: food,
    grams: grams,
    kcal: kcal.isFinite ? (kcal + 1e-9).round() : 0,
    protein: amount(food.protein),
    fat: amount(food.fat),
    carb: amount(food.carb),
    salt: amount(food.salt),
  );
}
