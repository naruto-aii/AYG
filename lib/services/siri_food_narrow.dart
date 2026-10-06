import '../utils/food_search_normalizer.dart';
import 'food_name_traits.dart';

/// 読み上げて選んでもらう上限。これより多くの別食品は、質問して絞る。
const int siriReadableChoices = 3;

/// 絞り込みの質問は、この回数で止める。
const int siriNarrowQuestionLimit = 3;

/// 絞り込みが受け取る食品。Siri の記録型とは切り離してある。
class FoodNarrowItem {
  const FoodNarrowItem({
    required this.id,
    required this.speakName,
    this.officialName,
    this.foodCode,
  });

  final String id;
  final String speakName;
  final String? officialName;
  final String? foodCode;
}

enum SiriFoodTurnKind { confirm, choose, ask }

class SiriFoodTurn {
  const SiriFoodTurn({
    required this.kind,
    required this.foods,
    required this.traits,
    this.question,
    this.axis,
    this.confident = true,
  });

  final SiriFoodTurnKind kind;
  final List<FoodNarrowItem> foods;
  final FoodNameTraits traits;
  final String? question;
  final String? axis;

  /// 別の食品の中から推測したときは false。確認してから登録する。
  final bool confident;
}

FoodNameTraits traitsOfNarrowItem(FoodNarrowItem food) {
  final text = '${food.speakName} ${food.officialName ?? ''}';
  return traitsFromFoodName(text, foodCode: food.foodCode);
}

/// 並んだ食品を、発話に合わせて減らし、次の一言を決める。
SiriFoodTurn decideSiriFoodTurn({
  required List<FoodNarrowItem> foods,
  required FoodNameTraits traits,
  required int roundsAsked,
}) {
  final pool = applyTraitFilters(foods, traits, traitsOfNarrowItem);
  if (pool.isEmpty) {
    return SiriFoodTurn(
      kind: SiriFoodTurnKind.confirm,
      foods: const [],
      traits: traits,
    );
  }
  final groups = _identityGroups(pool);
  if (pool.length == 1 || groups.length == 1) {
    return SiriFoodTurn(
      kind: SiriFoodTurnKind.confirm,
      foods: [representativeFood(pool, spokenKind: traits.kind)],
      traits: traits,
    );
  }
  if (pool.length <= siriReadableChoices) {
    return SiriFoodTurn(
      kind: SiriFoodTurnKind.choose,
      foods: pool,
      traits: traits,
    );
  }
  final group = _majorityGroup(pool);
  if (groups.length <= siriReadableChoices) {
    return SiriFoodTurn(
      kind: SiriFoodTurnKind.choose,
      foods: [
        for (final items in groups)
          representativeFood(items, spokenKind: traits.kind),
      ],
      traits: traits,
    );
  }
  final axis = _nextAxis(pool, traits, group);
  if (axis == null || roundsAsked >= siriNarrowQuestionLimit) {
    return SiriFoodTurn(
      kind: SiriFoodTurnKind.confirm,
      foods: [representativeFood(pool, spokenKind: traits.kind)],
      traits: traits,
      confident: false,
    );
  }
  return SiriFoodTurn(
    kind: SiriFoodTurnKind.ask,
    foods: pool,
    traits: traits,
    axis: axis,
    question: _question(axis, group),
  );
}

/// よく食べる形。同じ部位なら和牛・若鶏、皮なしを前にし、脂身そのものは後ろにする。
FoodNarrowItem representativeFood(
  List<FoodNarrowItem> foods, {
  String? spokenKind,
}) {
  final ranked = foods.asMap().entries.toList()
    ..sort((a, b) {
      final score = _representativeScore(
        a.value,
        spokenKind: spokenKind,
      ).compareTo(_representativeScore(b.value, spokenKind: spokenKind));
      if (score != 0) {
        return score;
      }
      return a.key.compareTo(b.key);
    });
  return ranked.first.value;
}

/// 生・ゆで・皮・品種の違いを除いた食品。同じなら聞き返さない。
String _identityKey(FoodNarrowItem food) {
  final traits = traitsOfNarrowItem(food);
  final code = food.foodCode;
  final group = code != null && code.length >= 2 ? code.substring(0, 2) : null;
  if (traits.cut != null && (group == '11' || traits.animal != null)) {
    return 'cut:${traits.animal ?? ''}:${traits.cut}';
  }
  return 'core:${_coreName(food.speakName)}';
}

String _coreName(String speakName) {
  var text = speakName.replaceAll(RegExp(r'（[^）]*）'), '');
  const drop = [
    '皮下脂肪なし',
    '脂身つき',
    '脂身',
    '皮なし',
    '皮つき',
    '赤肉',
    '乳用肥育牛',
    '輸入牛',
    '和牛',
    '若鶏',
    '若どり',
    'にわとり',
    '大型種肉',
    '中型種肉',
    '大型種',
    '中型種',
    '養殖',
    '副品目',
    '主品目',
    '結球葉',
    'から揚げ',
    '唐揚げ',
    '天ぷら',
    'てんぷら',
    'ソテー',
    'フライ',
    '水煮',
    '焼き',
    'ゆで',
    '茹で',
    '蒸し',
    '生',
  ];
  for (final word in drop) {
    text = text.replaceAll(word, '');
  }
  text = text.replaceAll(RegExp(r'\s+'), '');
  if (text.isEmpty) {
    return speakName;
  }
  return text;
}

bool _sameFamily(String a, String b) {
  if (a == b) {
    return true;
  }
  if (a.startsWith('cut:') || b.startsWith('cut:')) {
    return false;
  }
  final left = a.startsWith('core:') ? a.substring(5) : a;
  final right = b.startsWith('core:') ? b.substring(5) : b;
  if (left.length < 2 || right.length < 2) {
    return false;
  }
  return left.contains(right) || right.contains(left);
}

List<List<FoodNarrowItem>> _identityGroups(List<FoodNarrowItem> foods) {
  final keyed = <String, List<FoodNarrowItem>>{};
  final order = <String>[];
  for (final food in foods) {
    final key = _identityKey(food);
    final matched = order.cast<String?>().firstWhere(
      (have) => _sameFamily(have!, key),
      orElse: () => null,
    );
    if (matched == null) {
      order.add(key);
      keyed[key] = [food];
    } else {
      keyed[matched]!.add(food);
    }
  }
  return [for (final key in order) keyed[key]!];
}

String? _nextAxis(
  List<FoodNarrowItem> foods,
  FoodNameTraits traits,
  String? group,
) {
  if (group == '11' || _animals(foods).isNotEmpty) {
    if (_animals(foods).length >= 2 && traits.animal == null) {
      return 'animal';
    }
    if (_cuts(foods).length >= 2 && traits.cut == null) {
      return 'cut';
    }
    return null;
  }
  if (_kindClusters(foods).length >= 2 && traits.kind == null) {
    return 'kind';
  }
  return null;
}

String _question(String axis, String? group) {
  return switch (axis) {
    'animal' => '牛、豚、鶏のどれですか？',
    'cut' => 'どの部位ですか？',
    'kind' => switch (group) {
      '10' => '何の魚ですか？',
      '06' => '何の野菜ですか？',
      '07' => '何の果物ですか？',
      _ => '種類はどれですか？',
    },
    'cook' => switch (group) {
      '06' || '07' => '生かゆでですか？',
      _ => '生、焼き、ゆで、揚げのどれですか？',
    },
    _ => 'どれにしますか？',
  };
}

Set<String> _animals(List<FoodNarrowItem> foods) {
  return {
    for (final food in foods)
      if (traitsOfNarrowItem(food).animal != null)
        traitsOfNarrowItem(food).animal!,
  };
}

Set<String> _cuts(List<FoodNarrowItem> foods) {
  return {
    for (final food in foods)
      if (traitsOfNarrowItem(food).cut != null) traitsOfNarrowItem(food).cut!,
  };
}

/// 「はくさい」と「ながさきはくさい」は同じ集まりにする。
List<String> _kindClusters(List<FoodNarrowItem> foods) {
  final kinds = <String>[];
  for (final food in foods) {
    final kind = traitsOfNarrowItem(food).kind;
    if (kind == null || kind.isEmpty) {
      continue;
    }
    final folded = _foldKana(FoodSearchNormalizer.normalize(kind));
    final raw = _foldKana(kind);
    final key = folded.isEmpty ? raw : folded;
    if (key.isEmpty) {
      continue;
    }
    final absorbed = kinds.any(
      (have) => have.contains(key) || key.contains(have),
    );
    if (!absorbed) {
      kinds.add(key);
    }
  }
  return kinds;
}

String? _majorityGroup(List<FoodNarrowItem> foods) {
  final counts = <String, int>{};
  for (final food in foods) {
    final code = food.foodCode;
    if (code == null || code.length < 2) {
      continue;
    }
    final group = code.substring(0, 2);
    counts[group] = (counts[group] ?? 0) + 1;
  }
  String? best;
  var bestCount = 0;
  for (final entry in counts.entries) {
    if (entry.value > bestCount) {
      best = entry.key;
      bestCount = entry.value;
    }
  }
  return best;
}

int _representativeScore(FoodNarrowItem food, {String? spokenKind}) {
  // 正式名は「ばら 脂身つき」のように修飾が前に出る。表示名だけでよく食べる形を決める。
  final name = food.speakName;
  var score = 0;
  if (name.contains('脂身（') || name.contains(' 脂身')) {
    score += 40;
  }
  for (final word in const [
    '新巻き',
    '塩ざけ',
    '塩さけ',
    'イクラ',
    'すじこ',
    'めふん',
    '削り節',
    '缶詰',
    'くん製',
    'スモーク',
  ]) {
    if (name.contains(word)) {
      score += 12;
    }
  }
  if (name.contains('副品目') || name.contains('親・') || name.contains('（親')) {
    score += 8;
  }
  if (name.contains('輸入') || name.contains('乳用')) {
    score += 6;
  }
  if (name.contains('和牛') || name.contains('若鶏') || name.contains('若どり')) {
    score -= 10;
  }
  if (name.contains('皮なし')) {
    score -= 2;
  }
  if (name.contains('皮つき')) {
    score += 2;
  }
  final kind = traitsOfNarrowItem(food).kind;
  if (spokenKind != null && kind != null) {
    final spoken = _foldKana(FoodSearchNormalizer.normalize(spokenKind));
    final foodKind = _foldKana(FoodSearchNormalizer.normalize(kind));
    if (foodKind == spoken || kind == spokenKind) {
      score -= 8;
    } else if (foodKind.contains(spoken) || kind.contains(spokenKind)) {
      score += 4;
    }
  }
  return score;
}

String _foldKana(String text) {
  const from = 'がぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽ';
  const to = 'かきくけこさしすせそたちつてとはひふへほはひふへほ';
  final buffer = StringBuffer();
  for (final rune in text.runes) {
    final char = String.fromCharCode(rune);
    final at = from.indexOf(char);
    buffer.write(at >= 0 ? to[at] : char);
  }
  return buffer.toString();
}
