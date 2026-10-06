import '../utils/food_search_normalizer.dart';

/// 食品名から部位・調理・種類を取る。
///
/// 全食品に同じ規則を掛ける。食品ごとの言い換え表は持たない。
/// 検索の正規化は空白と長音を除くので、部位の照合もそちらに揃える。
class FoodNameTraits {
  const FoodNameTraits({this.animal, this.cut, this.cook, this.kind});

  /// `beef` / `pork` / `chicken`。
  final String? animal;

  /// `momo` や `mune` など、部位の呼び方。
  final String? cut;

  /// `raw` / `grilled` / `boiled` / `fried` / `steamed`。
  final String? cook;

  /// 食品名の先頭。魚なら種類、野菜ならその野菜。
  final String? kind;

  FoodNameTraits merge(FoodNameTraits newer) {
    return FoodNameTraits(
      animal: newer.animal ?? animal,
      cut: newer.cut ?? cut,
      cook: newer.cook ?? cook,
      kind: newer.kind ?? kind,
    );
  }
}

/// 食品の表示名と正式名から部位・調理・種類を取る。
FoodNameTraits traitsFromFoodName(String name, {String? foodCode}) {
  final group = foodCode != null && foodCode.length >= 2
      ? foodCode.substring(0, 2)
      : null;
  final animal = _animalOf(name, group: group);
  final cook = _cookOf(name);
  final cut = _cutOf(name, allowThigh: animal != null || group == '11');
  return FoodNameTraits(
    animal: animal,
    cut: cut,
    cook: cook,
    kind: _kindOf(name),
  );
}

/// 最初の発話から、すでに言われている部位・調理・種類を取る。
FoodNameTraits traitsFromUtterance(String name) {
  final compact = _compact(name);
  if (compact.isEmpty || _broadWords.contains(compact)) {
    final animal = _animalOf(compact, group: null);
    return FoodNameTraits(animal: animal);
  }
  final animal = _animalOf(compact, group: null);
  final cook = _cookOf(compact);
  final stripped = dropCookWords(compact);
  final cut = _cutOf(
    stripped,
    allowThigh: animal != null || _isJust(stripped, const ['もも', '腿', 'モモ']),
  );
  final kind = _utteranceKind(compact, animal: animal, cut: cut, cook: cook);
  return FoodNameTraits(animal: animal, cut: cut, cook: cook, kind: kind);
}

/// 聞き返しへの答え。部位・調理・種類のほか、分からないと中止も取る。
class SpokenFoodReply {
  const SpokenFoodReply({
    required this.traits,
    this.cancel = false,
    this.unknown = false,
  });

  final FoodNameTraits traits;
  final bool cancel;
  final bool unknown;
}

SpokenFoodReply parseSpokenFoodReply(String raw) {
  final compact = _compact(raw)
      .replaceAll(RegExp(r'(です|だよ|だね|かも|かな)$'), '')
      .replaceAll(RegExp(r'(やつ|もの|の)$'), '');
  if (compact.isEmpty) {
    return const SpokenFoodReply(traits: FoodNameTraits());
  }
  if (_cancelWords.contains(compact)) {
    return const SpokenFoodReply(traits: FoodNameTraits(), cancel: true);
  }
  if (_unknownWords.contains(compact)) {
    return const SpokenFoodReply(traits: FoodNameTraits(), unknown: true);
  }
  final cook = _cookOf(compact) ?? _spokenCook(compact);
  final animal = _animalOf(compact, group: null) ?? _spokenAnimal(compact);
  final cut = _cutOf(compact, allowThigh: true);
  if (animal != null || cut != null || cook != null) {
    return SpokenFoodReply(
      traits: FoodNameTraits(animal: animal, cut: cut, cook: cook),
    );
  }
  return SpokenFoodReply(traits: FoodNameTraits(kind: compact));
}

/// 調理の語を末尾から外した検索語。「牛ももの焼き」は「牛もも」になる。
String dropCookWords(String raw) {
  var text = _compact(raw);
  final suffixes = [
    'のから揚げ',
    'から揚げ',
    'の唐揚げ',
    '唐揚げ',
    'の天ぷら',
    '天ぷら',
    'のてんぷら',
    'てんぷら',
    'のフライ',
    'フライ',
    'の揚げ',
    '揚げ',
    'のからあげ',
    'からあげ',
    'の焼き',
    '焼き',
    '焼いた',
    'の焼',
    '焼',
    'のやき',
    'やいた',
    'やき',
    'のゆで',
    'ゆでた',
    'ゆで',
    'の茹で',
    '茹で',
    'の水煮',
    '水煮',
    'の蒸し',
    '蒸し',
    'のむし',
    'むし',
    'のソテー',
    'ソテー',
    'の生',
    '生',
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (final suffix in suffixes) {
      if (text.endsWith(suffix) && text.length > suffix.length) {
        text = text.substring(0, text.length - suffix.length);
        changed = true;
        break;
      }
    }
  }
  while (text.endsWith('の') && text.length > 1) {
    text = text.substring(0, text.length - 1);
  }
  return text;
}

/// 次に成分表へ投げる語。部位が付いた肉は「牛もも」のように短くする。
String foodSearchQuery(String original, FoodNameTraits traits) {
  final animal = traits.animal;
  final cut = traits.cut;
  if (animal != null && cut != null) {
    final animalWord = _animalWord[animal];
    final cutWord = _cutWord[cut];
    if (animalWord != null && cutWord != null) {
      return '$animalWord$cutWord';
    }
  }
  if (traits.kind != null && animal == null) {
    final kind = traits.kind!;
    final compact = _compact(original);
    if (_broadWords.contains(compact) || !compact.contains(kind)) {
      return kind;
    }
  }
  final dropped = dropCookWords(original);
  if (dropped.isNotEmpty) {
    return dropped;
  }
  return _compact(original);
}

/// 部位や調理が食品に合うか。種類は、片方がもう片方を含めば合う。
bool foodTraitsMatch(FoodNameTraits food, FoodNameTraits want) {
  if (want.animal != null && food.animal != want.animal) {
    return false;
  }
  if (want.cut != null && !_cutMatches(food.cut, want.cut!)) {
    return false;
  }
  if (want.cook != null && food.cook != want.cook) {
    return false;
  }
  if (want.kind != null && !_kindMatches(food.kind, want.kind!)) {
    return false;
  }
  return true;
}

/// 空にならない方だけ残す。漢字の「白菜」はひらがなの食品名に含まれないので、
/// その条件は外して、検索がすでに絞った一覧を使う。
List<T> applyTraitFilters<T>(
  List<T> foods,
  FoodNameTraits want,
  FoodNameTraits Function(T food) traitsOf,
) {
  var pool = foods;
  pool = _narrow(pool, traitsOf, (food) {
    if (want.animal == null) {
      return true;
    }
    return traitsOf(food).animal == want.animal;
  });
  pool = _narrow(pool, traitsOf, (food) {
    if (want.cut == null) {
      return true;
    }
    return _cutMatches(traitsOf(food).cut, want.cut!);
  });
  pool = _narrow(pool, traitsOf, (food) {
    if (want.kind == null) {
      return true;
    }
    return _kindMatches(traitsOf(food).kind, want.kind!);
  });
  pool = _narrow(pool, traitsOf, (food) {
    if (want.cook == null) {
      return true;
    }
    return traitsOf(food).cook == want.cook;
  });
  return pool;
}

List<T> _narrow<T>(
  List<T> pool,
  FoodNameTraits Function(T food) traitsOf,
  bool Function(T food) keep,
) {
  final next = pool.where(keep).toList();
  if (next.isEmpty) {
    return pool;
  }
  return next;
}

const _broadWords = {
  '牛肉',
  '豚肉',
  '鶏肉',
  '魚',
  '肉',
  '野菜',
  '果物',
  'さかな',
  'ぎゅうにく',
  'ぶたにく',
  'とりにく',
  'やさい',
  'くだもの',
};

const _cancelWords = {
  'やめる',
  'やめて',
  'やめ',
  'やめた',
  'キャンセル',
  'きゃんせる',
  '中止',
  '止めて',
  'やめてください',
  'もういい',
  '登録しない',
};

const _unknownWords = {
  'わからない',
  'わかんない',
  '分からない',
  '分かんない',
  'しらない',
  '知らない',
  'なんでも',
  'なんでもいい',
  '何でも',
  '何でもいい',
  'どれでも',
  'どれでもいい',
  '適当',
  'おすすめ',
  'おすすめで',
  '普通',
  'ふつう',
  'いつもの',
};

const _animalWord = {'beef': '牛', 'pork': '豚', 'chicken': '鶏'};

const _cutWord = {
  'momo': 'もも',
  'mune': 'むね',
  'bara': 'ばら',
  'rosu': 'ロース',
  'katarosu': 'かたロース',
  'ribu': 'リブロース',
  'sirloin': 'サーロイン',
  'hiki': 'ひき肉',
  'sasami': 'ささみ',
  'kata': 'かた',
  'hire': 'ひれ',
  'ranpu': 'ランプ',
  'sune': 'すね',
  'teba': '手羽',
};

const _cutPatterns = <(String, String)>[
  ('ひき肉', 'hiki'),
  ('ひきにく', 'hiki'),
  ('挽肉', 'hiki'),
  ('ミンチ', 'hiki'),
  ('みんち', 'hiki'),
  ('ささみ', 'sasami'),
  ('ササミ', 'sasami'),
  ('かたロース', 'katarosu'),
  ('肩ロース', 'katarosu'),
  ('かたろす', 'katarosu'),
  ('リブロース', 'ribu'),
  ('りぶろす', 'ribu'),
  ('サーロイン', 'sirloin'),
  ('さーろいん', 'sirloin'),
  ('さろいん', 'sirloin'),
  ('そともも', 'momo'),
  ('うちもも', 'momo'),
  ('ロース', 'rosu'),
  ('ろす', 'rosu'),
  ('ばら', 'bara'),
  ('バラ', 'bara'),
  ('むね', 'mune'),
  ('胸', 'mune'),
  ('もも', 'momo'),
  ('モモ', 'momo'),
  ('腿', 'momo'),
  ('ひれ', 'hire'),
  ('ヒレ', 'hire'),
  ('フィレ', 'hire'),
  ('ふぃれ', 'hire'),
  ('ランプ', 'ranpu'),
  ('らんぷ', 'ranpu'),
  ('手羽', 'teba'),
  ('てば', 'teba'),
  ('かた', 'kata'),
  ('肩', 'kata'),
  ('すね', 'sune'),
];

String? _animalOf(String name, {required String? group}) {
  if (_hasAny(name, const ['和牛', '牛肉', 'うし', '牛', 'ぎゅうにく', 'ぎゅう'])) {
    return 'beef';
  }
  if (_hasAny(name, const ['豚肉', 'ぶたにく', 'ぶた', '豚', 'とん'])) {
    if (name.contains('とんかつ') && !name.contains('豚')) {
      return null;
    }
    return 'pork';
  }
  if (_hasAny(name, const ['鶏肉', 'とりにく', 'にわとり', '若鶏', '若どり', 'わかどり', '鶏'])) {
    return 'chicken';
  }
  if (group == '11' && _hasAny(name, const ['とり'])) {
    return 'chicken';
  }
  return null;
}

String? _spokenAnimal(String compact) {
  return switch (compact) {
    '牛' || '牛肉' || 'ぎゅう' || 'ぎゅうにく' => 'beef',
    '豚' || '豚肉' || 'ぶた' || 'ぶたにく' => 'pork',
    '鶏' || '鶏肉' || 'とり' || 'とりにく' || 'チキン' => 'chicken',
    _ => null,
  };
}

String? _cookOf(String name) {
  final tokens = _tokens(name);
  final normalized = FoodSearchNormalizer.normalize(name);
  const rules = <(List<String>, String)>[
    (['から揚げ', 'からあげ', '唐揚げ', '唐揚', '天ぷら', 'てんぷら', 'フライ', 'ふらい'], 'fried'),
    (['揚げ', 'あげ'], 'fried'),
    (['ソテー', 'そて'], 'grilled'),
    (['焼き', '焼', 'やき', 'やいた', '焼いた'], 'grilled'),
    (['水煮', 'ゆで', '茹で', 'ゆでた', '茹でた'], 'boiled'),
    (['蒸し', 'むし', '蒸した'], 'steamed'),
    (['生', 'なま'], 'raw'),
  ];
  for (final rule in rules) {
    for (final word in rule.$1) {
      if (_cookMarked(name, normalized, tokens, word)) {
        return rule.$2;
      }
    }
  }
  return null;
}

String? _spokenCook(String compact) {
  const grilled = ['焼いた', '焼いて', 'やいた', 'やいて', 'グリル', 'ぐりる'];
  const boiled = ['ゆでた', '茹でた', '煮た', 'にた'];
  const fried = ['揚げた', 'あげた', 'からあげ', 'から揚げた'];
  const steamed = ['蒸した', 'むした'];
  const raw = ['生で', 'なまで'];
  if (grilled.contains(compact)) {
    return 'grilled';
  }
  if (boiled.contains(compact)) {
    return 'boiled';
  }
  if (fried.contains(compact)) {
    return 'fried';
  }
  if (steamed.contains(compact)) {
    return 'steamed';
  }
  if (raw.contains(compact)) {
    return 'raw';
  }
  return null;
}

bool _cookMarked(
  String name,
  String normalized,
  List<String> tokens,
  String word,
) {
  if (tokens.contains(word)) {
    return true;
  }
  if (name.endsWith(word) || name.endsWith('の$word')) {
    return true;
  }
  if (word == '生' || word == '焼' || word == 'なま') {
    return name.contains('（$word') ||
        name.contains('・$word') ||
        normalized.contains('・$word');
  }
  return name.contains('（$word') ||
      name.contains('・$word') ||
      name.contains(' $word');
}

String? _cutOf(String name, {required bool allowThigh}) {
  final normalized = FoodSearchNormalizer.normalize(name);
  final sources = [name, normalized];
  for (final pattern in _cutPatterns) {
    if (!allowThigh && pattern.$2 == 'momo') {
      continue;
    }
    for (final source in sources) {
      final at = source.indexOf(pattern.$1);
      if (at < 0) {
        continue;
      }
      if (_thighInsidePlum(source, at, pattern.$1)) {
        continue;
      }
      return pattern.$2;
    }
  }
  return null;
}

bool _thighInsidePlum(String source, int at, String word) {
  if (word != 'もも' && word != 'モモ') {
    return false;
  }
  if (at >= 1 && source.substring(at - 1, at) == 'す') {
    return true;
  }
  if (at >= 2 && source.substring(at - 2, at) == 'やま') {
    return true;
  }
  return false;
}

bool _cutMatches(String? foodCut, String spokenCut) {
  if (foodCut == null) {
    return false;
  }
  if (foodCut == spokenCut) {
    return true;
  }
  if (spokenCut == 'rosu' &&
      (foodCut == 'katarosu' || foodCut == 'ribu' || foodCut == 'rosu')) {
    return true;
  }
  if (spokenCut == 'kata' && (foodCut == 'kata' || foodCut == 'katarosu')) {
    return true;
  }
  return false;
}

String? _kindOf(String name) {
  final stripped = name
      .replaceAll(RegExp(r'（[^）]*）'), ' ')
      .replaceAll(RegExp(r'＜[^＞]*＞'), ' ')
      .replaceAll('　', ' ')
      .trim();
  if (stripped.isEmpty) {
    final fallback = name.trim();
    return fallback.isEmpty ? null : fallback;
  }
  final head = stripped.split(RegExp(r'\s+')).first;
  var kind = head;
  final patterns = [..._cutPatterns]
    ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
  for (final pattern in patterns) {
    kind = kind.replaceAll(pattern.$1, '');
  }
  kind = kind.trim();
  if (kind.isEmpty) {
    return head;
  }
  return kind;
}

String? _utteranceKind(
  String compact, {
  required String? animal,
  required String? cut,
  required String? cook,
}) {
  if (_broadWords.contains(compact)) {
    return null;
  }
  var rest = dropCookWords(compact);
  for (final word in const ['牛肉', '豚肉', '鶏肉', '和牛', '牛', '豚', '鶏']) {
    rest = rest.replaceAll(word, '');
  }
  final patterns = [..._cutPatterns]
    ..sort((a, b) => b.$1.length.compareTo(a.$1.length));
  for (final pattern in patterns) {
    rest = rest.replaceAll(pattern.$1, '');
  }
  rest = rest.replaceAll(RegExp(r'[のをはがにでとや]'), '');
  if (rest.isEmpty || _broadWords.contains(rest)) {
    return null;
  }
  if (animal != null && cut != null && rest.length <= 1) {
    return null;
  }
  return rest;
}

bool _kindMatches(String? foodKind, String spoken) {
  if (foodKind == null || foodKind.isEmpty || spoken.isEmpty) {
    return false;
  }
  final food = _foldKana(FoodSearchNormalizer.normalize(foodKind));
  final want = _foldKana(FoodSearchNormalizer.normalize(spoken));
  final foodRaw = _foldKana(foodKind);
  final wantRaw = _foldKana(spoken);
  if (food.isEmpty && foodRaw.isEmpty) {
    return false;
  }
  return food.contains(want) ||
      want.contains(food) ||
      foodRaw.contains(wantRaw) ||
      wantRaw.contains(foodRaw);
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

bool _hasAny(String name, List<String> words) {
  final normalized = FoodSearchNormalizer.normalize(name);
  for (final word in words) {
    if (name.contains(word) || normalized.contains(word)) {
      return true;
    }
  }
  return false;
}

bool _isJust(String text, List<String> words) {
  return words.contains(text);
}

List<String> _tokens(String name) {
  return name
      .replaceAll('（', ' ')
      .replaceAll('）', ' ')
      .replaceAll('(', ' ')
      .replaceAll(')', ' ')
      .replaceAll('・', ' ')
      .replaceAll('　', ' ')
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .toList();
}

String _compact(String raw) {
  return raw
      .trim()
      .replaceAll(' ', '')
      .replaceAll('　', '')
      .replaceAll(RegExp(r'[。．.！!？?、,]'), '');
}
