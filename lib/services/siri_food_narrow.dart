import '../utils/food_search_normalizer.dart';
import 'food_name_traits.dart';

/// 読み上げて選んでもらう上限。これより多いときは質問する。
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
  });

  final SiriFoodTurnKind kind;
  final List<FoodNarrowItem> foods;
  final FoodNameTraits traits;
  final String? question;
  final String? axis;
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
  if (pool.length == 1 || _detailed(pool, traits)) {
    return SiriFoodTurn(
      kind: SiriFoodTurnKind.confirm,
      foods: [representativeFood(pool, spokenKind: traits.kind)],
      traits: traits,
    );
  }
  final group = _majorityGroup(pool);
  final different = _greatlyDifferent(pool, group);
  if (pool.length <= siriReadableChoices && !different) {
    return SiriFoodTurn(
      kind: SiriFoodTurnKind.choose,
      foods: pool,
      traits: traits,
    );
  }
  final axis = _nextAxis(pool, traits, group);
  if (axis == null || roundsAsked >= siriNarrowQuestionLimit) {
    if (pool.length <= siriReadableChoices) {
      return SiriFoodTurn(
        kind: SiriFoodTurnKind.choose,
        foods: pool,
        traits: traits,
      );
    }
    return SiriFoodTurn(
      kind: SiriFoodTurnKind.confirm,
      foods: [representativeFood(pool, spokenKind: traits.kind)],
      traits: traits,
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

bool _detailed(List<FoodNarrowItem> foods, FoodNameTraits traits) {
  final group = _majorityGroup(foods);
  if (group == '11' || _animals(foods).isNotEmpty) {
    return traits.cut != null && traits.cook != null;
  }
  if (group == '10') {
    return traits.kind != null &&
        traits.cook != null &&
        _kindClusters(foods).length <= 1;
  }
  if (group == '06' || group == '07') {
    return traits.cook != null;
  }
  return false;
}

bool _greatlyDifferent(List<FoodNarrowItem> foods, String? group) {
  if (group == '11' || _animals(foods).length >= 2) {
    if (_animals(foods).length >= 2) {
      return true;
    }
    if (_cuts(foods).length >= 2) {
      return true;
    }
  }
  if (group == '10' || group == '06' || group == '07' || group == null) {
    if (_kindClusters(foods).length >= 2) {
      return true;
    }
  }
  return false;
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
    if (_cooks(foods).length >= 2 && traits.cook == null) {
      return 'cook';
    }
    return null;
  }
  if (_kindClusters(foods).length >= 2 && traits.kind == null) {
    return 'kind';
  }
  if (_cooks(foods).length >= 2 && traits.cook == null) {
    return 'cook';
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

Set<String> _cooks(List<FoodNarrowItem> foods) {
  return {
    for (final food in foods)
      if (traitsOfNarrowItem(food).cook != null) traitsOfNarrowItem(food).cook!,
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
