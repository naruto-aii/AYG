/// 今日のコーチが食事案に使う食品。
///
/// 画面の名前と提案単位。kcal と PFC は official_foods を読む。
/// ここに無い食品は出さない。
class CoachFoodCandidate {
  const CoachFoodCandidate({
    required this.foodCode,
    required this.displayName,
    required this.titleName,
    required this.amountName,
    required this.unitLabel,
    required this.unitGrams,
    required this.sortOrder,
    this.counter,
    this.contentsNote,
  });

  final String foodCode;

  /// 画面と食事記録に出す名前。
  final String displayName;

  /// 料理名にしないときの食品名。「白米とゆで卵」。
  final String titleName;

  /// 中身の量。「白米150g」「卵1個」。
  final String amountName;

  /// 1単位の呼び方。茶わん1杯、1個、100g。
  final String unitLabel;

  final int unitGrams;
  final int sortOrder;

  /// 1個、1枚のように数える単位。グラムだけの食品は null。
  final String? counter;

  /// 具なしおにぎりの「中身は米だけ」など。
  final String? contentsNote;

  CoachFoodCandidate copyWith({
    String? displayName,
    String? unitLabel,
    int? unitGrams,
    String? contentsNote,
  }) {
    return CoachFoodCandidate(
      foodCode: foodCode,
      displayName: displayName ?? this.displayName,
      titleName: titleName,
      amountName: amountName,
      unitLabel: unitLabel ?? this.unitLabel,
      unitGrams: unitGrams ?? this.unitGrams,
      sortOrder: sortOrder,
      counter: counter,
      contentsNote: contentsNote ?? this.contentsNote,
    );
  }
}

class CoachFoodNutrition {
  const CoachFoodNutrition({
    required this.foodCode,
    required this.kcal,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    this.officialName,
    this.baseAmount = 100,
  });

  final String foodCode;
  final String? officialName;
  final double kcal;
  final double proteinG;
  final double fatG;
  final double carbG;
  final double baseAmount;
}

class CoachFoodStock {
  const CoachFoodStock({required this.candidate, required this.nutrition});

  final CoachFoodCandidate candidate;
  final CoachFoodNutrition nutrition;

  double get unitKcal => _scale(nutrition.kcal);
  double get unitProteinG => _scale(nutrition.proteinG);
  double get unitFatG => _scale(nutrition.fatG);
  double get unitCarbG => _scale(nutrition.carbG);

  double _scale(double perBase) {
    final base = nutrition.baseAmount <= 0 ? 100.0 : nutrition.baseAmount;
    return perBase * candidate.unitGrams / base;
  }
}

abstract final class CoachFoodCatalog {
  static const candidates = <CoachFoodCandidate>[
    CoachFoodCandidate(
      foodCode: '01088',
      displayName: '白米（めし）',
      titleName: '白米',
      amountName: '白米',
      unitLabel: '茶わん1杯',
      unitGrams: 150,
      sortOrder: 1,
    ),
    CoachFoodCandidate(
      foodCode: '01085',
      displayName: '玄米（めし）',
      titleName: '玄米',
      amountName: '玄米',
      unitLabel: '茶わん1杯',
      unitGrams: 150,
      sortOrder: 2,
    ),
    CoachFoodCandidate(
      foodCode: '01111',
      displayName: '具なしおにぎり',
      titleName: '具なしおにぎり',
      amountName: '具なしおにぎり',
      unitLabel: '1個',
      unitGrams: 100,
      sortOrder: 3,
      counter: '個',
      contentsNote: '中身は米だけ',
    ),
    CoachFoodCandidate(
      foodCode: '01004',
      displayName: 'オートミール',
      titleName: 'オートミール',
      amountName: 'オートミール',
      unitLabel: '30g',
      unitGrams: 30,
      sortOrder: 4,
    ),
    CoachFoodCandidate(
      foodCode: '01026',
      displayName: '食パン（6枚切り）',
      titleName: '食パン',
      amountName: '食パン',
      unitLabel: '1枚',
      unitGrams: 60,
      sortOrder: 5,
      counter: '枚',
    ),
    CoachFoodCandidate(
      foodCode: '01039',
      displayName: 'うどん（ゆで）',
      titleName: 'うどん',
      amountName: 'うどん',
      unitLabel: '1玉',
      unitGrams: 250,
      sortOrder: 6,
      counter: '玉',
    ),
    CoachFoodCandidate(
      foodCode: '01128',
      displayName: 'そば（ゆで）',
      titleName: 'そば',
      amountName: 'そば',
      unitLabel: '1人前',
      unitGrams: 200,
      sortOrder: 7,
      counter: '人前',
    ),
    CoachFoodCandidate(
      foodCode: '01044',
      displayName: 'そうめん（ゆで）',
      titleName: 'そうめん',
      amountName: 'そうめん',
      unitLabel: '1人前',
      unitGrams: 200,
      sortOrder: 8,
      counter: '人前',
    ),
    CoachFoodCandidate(
      foodCode: '01048',
      displayName: '中華めん（ゆで）',
      titleName: '中華めん',
      amountName: '中華めん',
      unitLabel: '1玉',
      unitGrams: 200,
      sortOrder: 9,
      counter: '玉',
    ),
    CoachFoodCandidate(
      foodCode: '01064',
      displayName: 'スパゲッティ（ゆで）',
      titleName: 'スパゲッティ',
      amountName: 'スパゲッティ',
      unitLabel: '1人前',
      unitGrams: 200,
      sortOrder: 10,
      counter: '人前',
    ),
    CoachFoodCandidate(
      foodCode: '02008',
      displayName: 'さつまいも（焼き）',
      titleName: 'さつまいも',
      amountName: 'さつまいも',
      unitLabel: '中1本',
      unitGrams: 150,
      sortOrder: 11,
      counter: '本',
    ),
    CoachFoodCandidate(
      foodCode: '02018',
      displayName: 'じゃがいも（蒸し）',
      titleName: 'じゃがいも',
      amountName: 'じゃがいも',
      unitLabel: '中1個',
      unitGrams: 150,
      sortOrder: 12,
      counter: '個',
    ),
    CoachFoodCandidate(
      foodCode: '12005',
      displayName: 'ゆで卵',
      titleName: 'ゆで卵',
      amountName: '卵',
      unitLabel: '1個',
      unitGrams: 50,
      sortOrder: 13,
      counter: '個',
    ),
    CoachFoodCandidate(
      foodCode: '04032',
      displayName: '木綿豆腐',
      titleName: '木綿豆腐',
      amountName: '木綿豆腐',
      unitLabel: '半丁',
      unitGrams: 150,
      sortOrder: 14,
    ),
    CoachFoodCandidate(
      foodCode: '04033',
      displayName: '絹ごし豆腐',
      titleName: '絹ごし豆腐',
      amountName: '絹ごし豆腐',
      unitLabel: '半丁',
      unitGrams: 150,
      sortOrder: 15,
    ),
    CoachFoodCandidate(
      foodCode: '04046',
      displayName: '納豆',
      titleName: '納豆',
      amountName: '納豆',
      unitLabel: '1パック',
      unitGrams: 50,
      sortOrder: 16,
      counter: 'パック',
    ),
    CoachFoodCandidate(
      foodCode: '11288',
      displayName: '鶏むね（皮なし・焼き）',
      titleName: '鶏むね',
      amountName: '鶏むね',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 17,
    ),
    CoachFoodCandidate(
      foodCode: '11225',
      displayName: '鶏もも（皮なし・焼き）',
      titleName: '鶏もも',
      amountName: '鶏もも',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 18,
    ),
    CoachFoodCandidate(
      foodCode: '11229',
      displayName: '鶏ささみ（ゆで）',
      titleName: '鶏ささみ',
      amountName: '鶏ささみ',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 19,
    ),
    CoachFoodCandidate(
      foodCode: '11132',
      displayName: '豚もも（脂なし・焼き）',
      titleName: '豚もも',
      amountName: '豚もも',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 20,
    ),
    CoachFoodCandidate(
      foodCode: '11278',
      displayName: '豚ヒレ（赤肉・焼き）',
      titleName: '豚ヒレ',
      amountName: '豚ヒレ',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 21,
    ),
    CoachFoodCandidate(
      foodCode: '11270',
      displayName: '牛もも（脂なし・焼き）',
      titleName: '牛もも',
      amountName: '牛もも',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 22,
    ),
    CoachFoodCandidate(
      foodCode: '11291',
      displayName: '鶏ひき肉（焼き）',
      titleName: '鶏ひき肉',
      amountName: '鶏ひき肉',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 23,
    ),
    CoachFoodCandidate(
      foodCode: '10260',
      displayName: 'ツナ水煮（ライト）',
      titleName: 'ツナ水煮',
      amountName: 'ツナ水煮',
      unitLabel: '1罐',
      unitGrams: 70,
      sortOrder: 24,
      counter: '罐',
    ),
    CoachFoodCandidate(
      foodCode: '10136',
      displayName: 'さけ（焼き）',
      titleName: 'さけ',
      amountName: 'さけ',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 25,
    ),
    CoachFoodCandidate(
      foodCode: '10206',
      displayName: 'たら（焼き）',
      titleName: 'たら',
      amountName: 'たら',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 26,
    ),
    CoachFoodCandidate(
      foodCode: '10005',
      displayName: 'あじ（焼き）',
      titleName: 'あじ',
      amountName: 'あじ',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 27,
    ),
    CoachFoodCandidate(
      foodCode: '04053',
      displayName: '調製豆乳',
      titleName: '調製豆乳',
      amountName: '調製豆乳',
      unitLabel: 'コップ1杯',
      unitGrams: 200,
      sortOrder: 28,
      counter: '杯',
    ),
    CoachFoodCandidate(
      foodCode: '13003',
      displayName: '牛乳',
      titleName: '牛乳',
      amountName: '牛乳',
      unitLabel: 'コップ1杯',
      unitGrams: 200,
      sortOrder: 29,
      counter: '杯',
    ),
    CoachFoodCandidate(
      foodCode: '13005',
      displayName: '低脂肪牛乳',
      titleName: '低脂肪牛乳',
      amountName: '低脂肪牛乳',
      unitLabel: 'コップ1杯',
      unitGrams: 200,
      sortOrder: 30,
      counter: '杯',
    ),
    CoachFoodCandidate(
      foodCode: '13025',
      displayName: 'ヨーグルト（無糖）',
      titleName: 'ヨーグルト',
      amountName: 'ヨーグルト',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 31,
    ),
    CoachFoodCandidate(
      foodCode: '13053',
      displayName: 'ヨーグルト（低脂肪・無糖）',
      titleName: '低脂肪ヨーグルト',
      amountName: '低脂肪ヨーグルト',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 32,
    ),
    CoachFoodCandidate(
      foodCode: '13040',
      displayName: 'プロセスチーズ',
      titleName: 'プロセスチーズ',
      amountName: 'プロセスチーズ',
      unitLabel: '1切れ',
      unitGrams: 20,
      sortOrder: 33,
      counter: '切れ',
    ),
    CoachFoodCandidate(
      foodCode: '13033',
      displayName: 'カテージチーズ',
      titleName: 'カテージチーズ',
      amountName: 'カテージチーズ',
      unitLabel: '100g',
      unitGrams: 100,
      sortOrder: 34,
    ),
  ];

  static List<String> get codes => [
    for (final food in candidates) food.foodCode,
  ];

  static CoachFoodCandidate? find(String foodCode) {
    for (final food in candidates) {
      if (food.foodCode == foodCode) {
        return food;
      }
    }
    return null;
  }
}
