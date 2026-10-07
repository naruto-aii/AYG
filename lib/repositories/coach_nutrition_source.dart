import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/coach_food_catalog.dart';

/// 候補の栄養は official_foods から読む。読めなければカタログの100g値。
///
/// 量は portion_options かカタログの選択肢だけ。unit_grams では決めない。
/// coach_role が無い行と is_active が false の行は使わない。
/// 候補表が読めないときはカタログだけで提案できる。
abstract class CoachNutritionSource {
  Future<List<CoachFoodStock>> load();
}

class SupabaseCoachNutritionSource implements CoachNutritionSource {
  SupabaseCoachNutritionSource({this._client});

  final SupabaseClient? _client;

  @override
  Future<List<CoachFoodStock>> load() async {
    final client = _client ?? _currentClient();
    if (client == null) {
      return CoachFoodCatalog.stocks;
    }
    try {
      final nutrition = await _nutrition(client);
      final rows = await _candidateRows(client);
      return [
        for (final candidate in CoachFoodCatalog.candidates)
          if (_include(candidate, rows))
            CoachFoodStock(
              candidate: _apply(candidate, rows[candidate.foodCode]),
              nutrition:
                  nutrition[candidate.foodCode] ??
                  CoachFoodCatalog.stockFor(candidate).nutrition,
            ),
      ];
    } catch (_) {
      return CoachFoodCatalog.stocks;
    }
  }

  SupabaseClient? _currentClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, CoachFoodNutrition>> _nutrition(SupabaseClient client) async {
    try {
      final rows = await client
          .from('official_foods')
          .select(
            'food_code,name,kcal,protein_g,fat_g,carb_g,base_amount,salt_eq_g',
          )
          .inFilter('food_code', CoachFoodCatalog.codes);
      return _nutritionByCode(rows, saltColumn: true);
    } catch (_) {
      final rows = await client
          .from('official_foods')
          .select('food_code,name,kcal,protein_g,fat_g,carb_g,base_amount')
          .inFilter('food_code', CoachFoodCatalog.codes);
      return _nutritionByCode(rows, saltColumn: false);
    }
  }

  Future<Map<String, _CandidateRow>> _candidateRows(SupabaseClient client) async {
    try {
      final rows = await client
          .from('coach_food_candidates')
          .select(
            'food_code,display_name,unit_label,contents_note,coach_role,'
            'coach_subrole,is_green_yellow_vegetable,is_starchy_side,'
            'is_bread_or_noodle,portion_options,is_active',
          );
      return _rows(rows);
    } catch (_) {
      return const {};
    }
  }
}

class _CandidateRow {
  const _CandidateRow({
    required this.hasRole,
    required this.active,
    this.displayName,
    this.unitLabel,
    this.contentsNote,
    this.role,
    this.subrole,
    this.green,
    this.starchy,
    this.bread,
    this.portions = const [],
  });

  final bool hasRole;
  final bool active;
  final String? displayName;
  final String? unitLabel;
  final String? contentsNote;
  final CoachFoodRole? role;
  final CoachFoodSubrole? subrole;
  final bool? green;
  final bool? starchy;
  final bool? bread;
  final List<CoachPortionOption> portions;
}

bool _include(CoachFoodCandidate candidate, Map<String, _CandidateRow> rows) {
  final row = rows[candidate.foodCode];
  if (row == null) {
    return true;
  }
  return row.active && row.hasRole;
}

CoachFoodCandidate _apply(CoachFoodCandidate candidate, _CandidateRow? row) {
  if (row == null || !row.active || !row.hasRole) {
    return candidate;
  }
  return candidate.copyWith(
    displayName: row.displayName,
    unitLabel: row.unitLabel,
    contentsNote: row.contentsNote,
    role: row.role,
    subrole: row.subrole,
    isGreenYellowVegetable: row.green,
    isStarchySide: row.starchy,
    isBreadOrNoodle: row.bread,
    portions: row.portions.isEmpty ? null : row.portions,
  );
}

Map<String, _CandidateRow> _rows(Object? rows) {
  final parsed = <String, _CandidateRow>{};
  if (rows is! List) {
    return parsed;
  }
  for (final row in rows) {
    if (row is! Map) {
      continue;
    }
    final code = row['food_code']?.toString();
    if (code == null || code.isEmpty) {
      continue;
    }
    final role = _role(row['coach_role']);
    parsed[code] = _CandidateRow(
      hasRole: role != null,
      active: row['is_active'] != false,
      displayName: _text(row['display_name']),
      unitLabel: _text(row['unit_label']),
      contentsNote: _text(row['contents_note']),
      role: role,
      subrole: _subrole(row['coach_subrole']),
      green: row['is_green_yellow_vegetable'] == true,
      starchy: row['is_starchy_side'] == true,
      bread: row['is_bread_or_noodle'] == true,
      portions: _portions(row['portion_options']),
    );
  }
  return parsed;
}

Map<String, CoachFoodNutrition> _nutritionByCode(
  Object? rows, {
  required bool saltColumn,
}) {
  final nutrition = <String, CoachFoodNutrition>{};
  if (rows is! List) {
    return nutrition;
  }
  for (final row in rows) {
    if (row is! Map) {
      continue;
    }
    final code = row['food_code']?.toString();
    final kcal = _double(row['kcal']);
    final protein = _double(row['protein_g']);
    final fat = _double(row['fat_g']);
    final carb = _double(row['carb_g']);
    if (code == null ||
        kcal == null ||
        protein == null ||
        fat == null ||
        carb == null) {
      continue;
    }
    final catalog = CoachFoodCatalog.find(code);
    nutrition[code] = CoachFoodNutrition(
      foodCode: code,
      officialName: _text(row['name']),
      kcal: kcal,
      proteinG: protein,
      fatG: fat,
      carbG: carb,
      saltEqG: saltColumn
          ? (_double(row['salt_eq_g']) ?? catalog?.saltPer100g ?? 0)
          : (catalog?.saltPer100g ?? 0),
      baseAmount: _double(row['base_amount']) ?? 100,
    );
  }
  return nutrition;
}

List<CoachPortionOption> _portions(Object? raw) {
  if (raw is! List) {
    return const [];
  }
  final portions = <CoachPortionOption>[];
  for (final item in raw) {
    if (item is! Map) {
      continue;
    }
    final tier = _tier(item['tier']);
    final label = _text(item['label']);
    final grams = _int(item['grams']);
    if (tier == null || label == null || grams == null || grams <= 0) {
      continue;
    }
    portions.add(CoachPortionOption(tier: tier, label: label, grams: grams));
  }
  return portions;
}

CoachFoodRole? _role(Object? value) {
  return switch (value?.toString()) {
    'staple' => CoachFoodRole.staple,
    'main' => CoachFoodRole.main,
    'side' => CoachFoodRole.side,
    'dairy' => CoachFoodRole.dairy,
    'fruit' => CoachFoodRole.fruit,
    _ => null,
  };
}

CoachFoodSubrole? _subrole(Object? value) {
  return switch (value?.toString()) {
    'grain' => CoachFoodSubrole.grain,
    'meat' => CoachFoodSubrole.meat,
    'fish' => CoachFoodSubrole.fish,
    'egg' => CoachFoodSubrole.egg,
    'soy' => CoachFoodSubrole.soy,
    'vegetable' => CoachFoodSubrole.vegetable,
    'mushroom' => CoachFoodSubrole.mushroom,
    'potato' => CoachFoodSubrole.potato,
    'milk' => CoachFoodSubrole.milk,
    'yogurt' => CoachFoodSubrole.yogurt,
    'cheese' => CoachFoodSubrole.cheese,
    'fruit' => CoachFoodSubrole.fruit,
    _ => null,
  };
}

CoachPortionTier? _tier(Object? value) {
  return switch (value?.toString()) {
    'light' => CoachPortionTier.light,
    'standard' => CoachPortionTier.standard,
    'hearty' => CoachPortionTier.hearty,
    'any' => CoachPortionTier.any,
    _ => null,
  };
}

String? _text(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value == null) {
    return null;
  }
  return double.tryParse(value.toString());
}

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value == null) {
    return null;
  }
  return int.tryParse(value.toString());
}
