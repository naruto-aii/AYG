import '../models/food_entry.dart';
import '../models/food_entry_source.dart';
import '../models/food_unit_type.dart';
import '../state/app_controller.dart';
import '../utils/meal_slot.dart';

/// 画面に出した1品。保存する数値は、この値と同じにする。
class CookIngredient {
  const CookIngredient({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.source,
    this.foodCode,
    this.officialName,
    this.extra = false,
  });

  final String name;
  final int grams;
  final int kcal;
  final double proteinG;
  final double fatG;
  final double carbG;

  /// db は成分表。ai は成分表に無い食品の目安。
  final String source;
  final String? foodCode;
  final String? officialName;
  final bool extra;

  bool get fromDatabase => source == 'db' && (foodCode ?? '').isNotEmpty;
}

class CookDish {
  const CookDish({
    required this.kind,
    required this.name,
    required this.steps,
    required this.extras,
    required this.ingredients,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.gapKcal,
    required this.gapProteinG,
    required this.gapFatG,
    required this.gapCarbG,
    this.withinTolerance = false,
  });

  /// on_hand か extra。
  final String kind;
  final String name;
  final List<String> steps;
  final List<String> extras;
  final List<CookIngredient> ingredients;
  final int kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final int gapKcal;
  final double gapProteinG;
  final double gapFatG;
  final double gapCarbG;

  /// サーバが kcal ±10%、P/F/C は ±15% か ±5g の広い方、に入ったとき true。
  final bool withinTolerance;
}

class CookModelCallUsage {
  const CookModelCallUsage({
    required this.inputTokens,
    required this.outputTokens,
    required this.latencyMs,
  });

  final int inputTokens;
  final int outputTokens;
  final int latencyMs;
}

class CookCoachResult {
  const CookCoachResult({
    required this.patterns,
    required this.retried,
    required this.calls,
  });

  final List<CookDish> patterns;
  final bool retried;
  final List<CookModelCallUsage> calls;
}

const cookCoachCapMessage = '本日の上限に達しました';

/// 目標までの差。正はまだ足りない分。
String cookKcalGapLabel(num gapKcal) {
  final gap = gapKcal.round();
  if (gap == 0) {
    return '目標どおり';
  }
  if (gap > 0) {
    return 'あと＋${gap}kcal';
  }
  return '目標より${gap.abs()}kcal多い';
}

String cookMacroGapLabel(String name, num gapG) {
  final gap = gapG.round();
  if (gap == 0) {
    return '$name 目標どおり';
  }
  if (gap > 0) {
    return '$name あと＋${gap}g';
  }
  return '$name 目標より${gap.abs()}g多い';
}

/// チップ、キーボード、音声入力の文を食材名に分ける。
List<String> cookIngredientNames(String raw) {
  final parts = raw.split(RegExp(r'[、,，\n]'));
  final names = <String>[];
  final seen = <String>{};
  for (final part in parts) {
    final name = part.trim();
    if (name.isEmpty || name.length > 40 || !seen.add(name)) {
      continue;
    }
    names.add(name);
  }
  return names;
}

CookCoachResult? parseCookCoachResult(Object? data) {
  if (data is! Map) {
    return null;
  }
  final patterns = data['patterns'];
  if (patterns is! List || patterns.isEmpty) {
    return null;
  }
  final dishes = <CookDish>[];
  for (final item in patterns) {
    final dish = _dish(item);
    if (dish == null) {
      return null;
    }
    dishes.add(dish);
  }
  final calls = <CookModelCallUsage>[];
  final rawCalls = data['calls'];
  if (rawCalls is List) {
    for (final item in rawCalls) {
      if (item is! Map) {
        continue;
      }
      calls.add(
        CookModelCallUsage(
          inputTokens: _int(item['input_tokens']) ?? 0,
          outputTokens: _int(item['output_tokens']) ?? 0,
          latencyMs: _int(item['latency_ms']) ?? 0,
        ),
      );
    }
  }
  return CookCoachResult(
    patterns: dishes,
    retried: data['retried'] == true,
    calls: calls,
  );
}

/// 画面の1品を、食事の outbox に載せる行にする。グラムと栄養は画面の値のまま。
List<FoodEntry> foodEntriesForCookDish({
  required CookDish dish,
  required String mealGroupId,
  required DateTime loggedAt,
  required List<String> ids,
}) {
  if (ids.length != dish.ingredients.length) {
    throw StateError('cook dish ids');
  }
  return [
    for (var i = 0; i < dish.ingredients.length; i++)
      _entry(
        item: dish.ingredients[i],
        id: ids[i],
        mealGroupId: mealGroupId,
        mealGroupName: dish.name,
        sortOrder: i + 1,
        loggedAt: loggedAt,
      ),
  ];
}

/// 既存の食事保存（addFoodEntriesBatch）へ、画面と同じ数値で渡す。
Future<List<String>> saveCookCoachDish({
  required AppController controller,
  required CookDish dish,
  required DateTime loggedAt,
}) async {
  if (dish.ingredients.isEmpty) {
    throw StateError('cook dish empty');
  }
  final mealGroupId = controller.generateId();
  final ids = [for (final _ in dish.ingredients) controller.generateId()];
  final entries = foodEntriesForCookDish(
    dish: dish,
    mealGroupId: mealGroupId,
    loggedAt: loggedAt,
    ids: ids,
  );
  await controller.addFoodEntriesBatch(entries);
  return ids;
}

FoodEntry _entry({
  required CookIngredient item,
  required String id,
  required String mealGroupId,
  required String mealGroupName,
  required int sortOrder,
  required DateTime loggedAt,
}) {
  final grams = item.grams.toDouble();
  return FoodEntry(
    id: id,
    name: item.name,
    kcalPerBase: item.kcal.toDouble(),
    proteinPerBase: item.proteinG,
    fatPerBase: item.fatG,
    carbPerBase: item.carbG,
    baseAmount: grams,
    unitType: FoodUnitType.g,
    consumedAmount: grams,
    sourceType: item.fromDatabase
        ? FoodEntrySource.mextSfct
        : FoodEntrySource.manual,
    officialFoodCode: item.fromDatabase ? item.foodCode : null,
    officialFoodName: item.fromDatabase ? item.officialName : null,
    mealGroupId: mealGroupId,
    mealGroupName: mealGroupName,
    sortOrder: sortOrder,
    loggedAt: loggedAt,
  );
}

CookDish? _dish(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final name = raw['name'];
  final kind = raw['kind'];
  final steps = raw['steps'];
  final ingredients = raw['ingredients'];
  if (name is! String || name.trim().isEmpty || kind is! String) {
    return null;
  }
  if (steps is! List || ingredients is! List || ingredients.isEmpty) {
    return null;
  }
  final items = <CookIngredient>[];
  for (final item in ingredients) {
    final parsed = _ingredient(item);
    if (parsed == null) {
      return null;
    }
    items.add(parsed);
  }
  return CookDish(
    kind: kind,
    name: name.trim(),
    steps: [
      for (final step in steps)
        if (step is String && step.trim().isNotEmpty) step.trim(),
    ],
    extras: [
      for (final extra in (raw['extras'] as List?) ?? const [])
        if (extra is String && extra.trim().isNotEmpty) extra.trim(),
    ],
    ingredients: items,
    kcal: _int(raw['kcal']) ?? 0,
    proteinG: _double(raw['protein_g']) ?? 0,
    fatG: _double(raw['fat_g']) ?? 0,
    carbG: _double(raw['carb_g']) ?? 0,
    gapKcal: _int(raw['gap_kcal']) ?? 0,
    gapProteinG: _double(raw['gap_protein_g']) ?? 0,
    gapFatG: _double(raw['gap_fat_g']) ?? 0,
    gapCarbG: _double(raw['gap_carb_g']) ?? 0,
    withinTolerance: raw['within_tolerance'] == true,
  );
}

CookIngredient? _ingredient(Object? raw) {
  if (raw is! Map) {
    return null;
  }
  final name = raw['name'];
  final grams = _int(raw['grams']);
  final kcal = _int(raw['kcal']);
  if (name is! String || name.trim().isEmpty || grams == null || grams <= 0) {
    return null;
  }
  if (kcal == null || kcal < 0) {
    return null;
  }
  final code = raw['food_code'];
  final official = raw['official_name'];
  return CookIngredient(
    name: name.trim(),
    grams: grams,
    kcal: kcal,
    proteinG: _double(raw['protein_g']) ?? 0,
    fatG: _double(raw['fat_g']) ?? 0,
    carbG: _double(raw['carb_g']) ?? 0,
    source: raw['source'] == 'db' ? 'db' : 'ai',
    foodCode: code is String && code.isNotEmpty ? code : null,
    officialName: official is String && official.isNotEmpty ? official : null,
    extra: raw['extra'] == true,
  );
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return null;
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

String cookSlotWire(MealSlot slot) => slot.name;
