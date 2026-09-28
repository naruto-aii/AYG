/// 食品成分表の1行と、検索で当たった別名。
class OfficialFoodMatch {
  const OfficialFoodMatch({
    required this.foodCode,
    required this.name,
    this.displayName,
    this.foodGroup,
    this.indexNo,
    this.reading,
    this.baseAmount = 100,
    this.unitType = 'g',
    this.kcal,
    this.proteinG,
    this.fatG,
    this.carbG,
    this.fiberG,
    this.saltEqG,
    this.matchedAlias,
    this.matchedAliasReading,
    this.matchRank = 9,
    this.priority = 100,
    this.isCandidate = false,
    this.candidateRank,
  });

  final String foodCode;
  final String name;
  final String? displayName;
  final String? foodGroup;
  final String? indexNo;
  final String? reading;
  final double baseAmount;
  final String unitType;
  final double? kcal;
  final double? proteinG;
  final double? fatG;
  final double? carbG;
  final double? fiberG;
  final double? saltEqG;
  final String? matchedAlias;
  final String? matchedAliasReading;
  final int matchRank;
  final int priority;
  final bool isCandidate;
  final int? candidateRank;

  /// 記録に残す名前。別名で当たったときはその別名。
  String get recordName {
    final alias = matchedAlias?.trim();
    if (alias != null && alias.isNotEmpty) {
      return alias;
    }
    return name;
  }

  factory OfficialFoodMatch.fromRpc(Map<String, dynamic> row) {
    return OfficialFoodMatch(
      foodCode: row['food_code']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      displayName: _text(row['display_name']),
      foodGroup: _text(row['food_group']),
      indexNo: _text(row['index_no']),
      reading: _text(row['reading']),
      baseAmount: _number(row['base_amount']) ?? 100,
      unitType: _text(row['unit_type']) ?? 'g',
      kcal: _number(row['kcal']),
      proteinG: _number(row['protein_g']),
      fatG: _number(row['fat_g']),
      carbG: _number(row['carb_g']),
      fiberG: _number(row['fiber_g']),
      saltEqG: _number(row['salt_eq_g']),
      matchedAlias: _text(row['matched_alias']),
      matchedAliasReading: _text(row['matched_alias_reading']),
      matchRank: _number(row['match_rank'])?.round() ?? 9,
      isCandidate: _bool(row['is_candidate']),
      candidateRank: _number(row['candidate_rank'])?.round(),
    );
  }

  static String? _text(Object? value) {
    if (value == null) {
      return null;
    }
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static bool _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final text = value?.toString().toLowerCase();
    return text == 'true' || text == 't' || text == '1';
  }

  static double? _number(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }
}

/// 別名辞書の1行。ランキングのテストとアプリ内照合で使う。
class OfficialFoodAlias {
  const OfficialFoodAlias({
    required this.alias,
    required this.normalized,
    this.reading,
    this.priority = 100,
    this.isCandidate = false,
    this.candidateRank,
  });

  final String alias;
  final String normalized;
  final String? reading;
  final int priority;
  final bool isCandidate;
  final int? candidateRank;
}
