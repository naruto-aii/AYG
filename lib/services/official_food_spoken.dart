import '../models/official_food.dart';
import '../utils/food_search_normalizer.dart';

/// 主要食品の手動の別名。マイグレーションの spoken_manual_v1 と同じ。
class ManualSpokenAlias {
  const ManualSpokenAlias({
    required this.foodCode,
    required this.alias,
    required this.reading,
    this.isCandidate = false,
    this.candidateRank,
  });

  final String foodCode;
  final String alias;
  final String reading;
  final bool isCandidate;
  final int? candidateRank;

  OfficialFoodAlias toAlias() {
    return OfficialFoodAlias(
      alias: alias,
      reading: reading,
      normalized: FoodSearchNormalizer.normalize(alias),
      priority: isCandidate ? 40 : 10,
      isCandidate: isCandidate,
      candidateRank: candidateRank,
    );
  }
}

const manualSpokenAliases = [
  ManualSpokenAlias(foodCode: '11227', alias: '鶏ささみ', reading: 'とりささみ'),
  ManualSpokenAlias(foodCode: '11227', alias: 'とりささみ', reading: 'とりささみ'),
  ManualSpokenAlias(foodCode: '11227', alias: 'さささみ', reading: 'さささみ'),
  ManualSpokenAlias(foodCode: '01088', alias: '白飯', reading: 'しろめし'),
  ManualSpokenAlias(foodCode: '01088', alias: '白いご飯', reading: 'しろいごはん'),
  ManualSpokenAlias(foodCode: '01088', alias: 'ごっはん', reading: 'ごっはん'),
  ManualSpokenAlias(
    foodCode: '11220',
    alias: 'サラチキ',
    reading: 'さらちき',
    isCandidate: true,
    candidateRank: 1,
  ),
  ManualSpokenAlias(
    foodCode: '11288',
    alias: 'サラチキ',
    reading: 'さらちき',
    isCandidate: true,
    candidateRank: 2,
  ),
  ManualSpokenAlias(foodCode: '11227', alias: 'さざみ', reading: 'さざみ'),
  ManualSpokenAlias(foodCode: '11227', alias: 'ささみい', reading: 'ささみい'),
  ManualSpokenAlias(foodCode: '12004', alias: 'たまこ', reading: 'たまこ'),
  ManualSpokenAlias(foodCode: '07107', alias: 'ばななな', reading: 'ばななな'),
  ManualSpokenAlias(foodCode: '13003', alias: 'ぎゅうにゅ', reading: 'ぎゅうにゅ'),
  ManualSpokenAlias(foodCode: '04046', alias: 'なっと', reading: 'なっと'),
  ManualSpokenAlias(foodCode: '01088', alias: 'ごはんん', reading: 'ごはんん'),
];


/// 成分表の正式名から口語名を作る。SQL の `official_food_spoken_name` と同じ。
const spokenFoodStopTokens = {
  '生',
  'なま',
  'ゆで',
  '茹で',
  '焼き',
  '焼',
  '乾',
  '乾燥',
  '水煮',
  '皮なし',
  '皮つき',
  '果実',
  '葉',
  '根',
  '塊茎',
  '塊根',
  '普通',
  '生鮮',
  '缶詰',
  '通年平均',
  '副品目',
  '主品目',
};

String officialFoodSpokenName(String? raw) {
  var text = raw ?? '';
  text = text.replaceAll(RegExp('＜[^＞]*＞'), ' ');
  text = text.replaceAll(RegExp(r'［[^］]*］'), ' ');
  text = text.replaceAll(RegExp('（[^）]*）'), ' ');
  text = text.replaceAll(RegExp(r'\([^)]*\)'), ' ');
  text = text.replaceAll(RegExp(r'[　\s]+'), ' ').trim();
  final kept = StringBuffer();
  for (final token in text.split(' ')) {
    if (token.isEmpty || spokenFoodStopTokens.contains(token)) {
      continue;
    }
    if (token.runes.length < 2) {
      continue;
    }
    kept.write(token);
  }
  return kept.toString();
}

/// 口語名そのものと、その中の3文字以上の読み。
List<String> officialFoodSpokenAliases(String? raw) {
  final spoken = officialFoodSpokenName(raw);
  final aliases = <String>{};
  if (spoken.runes.length >= 3) {
    aliases.add(spoken);
  }
  for (final match in RegExp('[ぁ-ゖァ-ヺー]{3,}').allMatches(spoken)) {
    final kana = match.group(0)!;
    if (FoodSearchNormalizer.normalize(kana).runes.length >= 3) {
      aliases.add(kana);
    }
  }
  return aliases.toList();
}
