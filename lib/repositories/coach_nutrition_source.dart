import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/coach_food_catalog.dart';

/// 候補の栄養は official_foods から読む。候補表がまだ無くても名前はカタログを使う。
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
      return const [];
    }
    try {
      final nutritionRows = await client
          .from('official_foods')
          .select('food_code,name,kcal,protein_g,fat_g,carb_g,base_amount')
          .inFilter('food_code', CoachFoodCatalog.codes);
      final nutrition = _nutritionByCode(nutritionRows);
      final overrides = await _candidateOverrides(client);
      return [
        for (final candidate in CoachFoodCatalog.candidates)
          if (nutrition[candidate.foodCode] case final values?)
            CoachFoodStock(
              candidate: _applyOverride(
                candidate,
                overrides[candidate.foodCode],
              ),
              nutrition: values,
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  SupabaseClient? _currentClient() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, _CandidateOverride>> _candidateOverrides(
    SupabaseClient client,
  ) async {
    try {
      final rows = await client
          .from('coach_food_candidates')
          .select('food_code,display_name,unit_label,unit_grams,contents_note');
      final overrides = <String, _CandidateOverride>{};
      for (final row in rows) {
        final code = row['food_code']?.toString();
        final grams = _int(row['unit_grams']);
        if (code == null || grams == null || grams <= 0) {
          continue;
        }
        overrides[code] = _CandidateOverride(
          displayName: _text(row['display_name']),
          unitLabel: _text(row['unit_label']),
          unitGrams: grams,
          contentsNote: _text(row['contents_note']),
        );
      }
      return overrides;
    } catch (_) {
      return const {};
    }
  }
}

class _CandidateOverride {
  const _CandidateOverride({
    required this.unitGrams,
    this.displayName,
    this.unitLabel,
    this.contentsNote,
  });

  final String? displayName;
  final String? unitLabel;
  final int unitGrams;
  final String? contentsNote;
}

CoachFoodCandidate _applyOverride(
  CoachFoodCandidate candidate,
  _CandidateOverride? override,
) {
  if (override == null) {
    return candidate;
  }
  return candidate.copyWith(
    displayName: override.displayName,
    unitLabel: override.unitLabel,
    unitGrams: override.unitGrams,
    contentsNote: override.contentsNote,
  );
}

Map<String, CoachFoodNutrition> _nutritionByCode(Object? rows) {
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
    nutrition[code] = CoachFoodNutrition(
      foodCode: code,
      officialName: _text(row['name']),
      kcal: kcal,
      proteinG: protein,
      fatG: fat,
      carbG: carb,
      baseAmount: _double(row['base_amount']) ?? 100,
    );
  }
  return nutrition;
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
