import '../utils/food_search_normalizer.dart';

/// 発話からフィラーと言い直しを除いた解釈。
///
/// 区切りで孤立したフィラーだけを落とす。食品名の中の「あ」は消さない。
/// 「ささ、あー、ささみ」は後の語が前で始まるので「ささみ」。
/// 「ささ、あー、み」は断片を連結して「ささみ」。
/// 量の「ひゃく、えー、グラム」も同じ手順で「ひゃくグラム」になる。
List<String> siriSpeechInterpretations(String raw) {
  final tokens = _contentTokens(raw);
  if (tokens.isEmpty) {
    return const [];
  }
  final concatenated = tokens.join();
  final adopted = _adoptLater(tokens).join();
  final interpretations = <String>[];
  void add(String text) {
    if (text.isEmpty || interpretations.contains(text)) {
      return;
    }
    interpretations.add(text);
  }

  add(adopted);
  add(concatenated);
  return interpretations;
}

/// 単位の直前にあるひらがなの数を、数字に置き換える。
///
/// 「ひゃくグラム」は「100グラム」。食品名の途中は単位が無いので変えない。
String foldSiriSpokenQuantities(String text) {
  var result = text;
  for (final unit in _quantityUnits) {
    var from = 0;
    while (from < result.length) {
      final at = result.indexOf(unit, from);
      if (at < 0) {
        break;
      }
      final number = _japaneseNumberBefore(result, at);
      if (number == null) {
        from = at + unit.length;
        continue;
      }
      final digits = '${number.value}';
      result = result.replaceRange(number.start, at, digits);
      from = number.start + digits.length + unit.length;
    }
  }
  return result;
}

const List<String> _fillerSurfaces = [
  'あ',
  'あー',
  'あぁ',
  'ああ',
  'あっ',
  'あ〜',
  'あ～',
  'え',
  'えー',
  'えぇ',
  'ええ',
  'えっ',
  'え〜',
  'えっと',
  'えーっと',
  'えーと',
  'えと',
  'うーん',
  'ううん',
  'うん',
  'んー',
  'んん',
  'ん',
  'あの',
  'あのー',
  'あのう',
  'あのね',
  'その',
  'そのー',
  'そのね',
  'まあ',
  'まー',
  'まぁ',
  'なんか',
  'なんかー',
  'なんかね',
  'えっとね',
  'えーっとね',
  'えーとね',
];

final Set<String> _fillerKeys = {
  for (final surface in _fillerSurfaces) _fillerKey(surface),
};

const List<String> _quantityUnits = [
  'ミリリットル',
  'キロメートル',
  'グラム',
  '分間',
  '食分',
  'ml',
  'mL',
  'ML',
  'ｍｌ',
  'km',
  'KM',
  '㎞',
  'キロ',
  '個',
  'こ',
  'コ',
  '食',
  '分',
  '回',
  'g',
  'G',
  'ｇ',
];

const Map<String, int> _numberOnes = {
  'れい': 0,
  'ゼロ': 0,
  'いち': 1,
  'に': 2,
  'さん': 3,
  'よん': 4,
  'し': 4,
  'ご': 5,
  'ろく': 6,
  'なな': 7,
  'しち': 7,
  'はち': 8,
  'きゅう': 9,
  'く': 9,
};

const Map<String, int> _numberUnits = {
  'せん': 1000,
  'ぜん': 1000,
  'ひゃく': 100,
  'びゃく': 100,
  'ぴゃく': 100,
  'じゅう': 10,
  'じゅっ': 10,
  'じっ': 10,
};

List<String> _contentTokens(String raw) {
  final tokens = <String>[];
  final buffer = StringBuffer();
  final characters = raw.split('');
  for (var index = 0; index < characters.length; index += 1) {
    final character = characters[index];
    final previous = index == 0 ? '' : characters[index - 1];
    final next = index + 1 < characters.length ? characters[index + 1] : '';
    if (_isDelimiter(character, previous: previous, next: next)) {
      _flushToken(buffer, tokens);
      continue;
    }
    buffer.write(character);
  }
  _flushToken(buffer, tokens);
  return tokens;
}

void _flushToken(StringBuffer buffer, List<String> tokens) {
  final token = buffer.toString().trim();
  buffer.clear();
  if (token.isEmpty || _isFiller(token)) {
    return;
  }
  tokens.add(token);
}

bool _isDelimiter(String character, {required String previous, required String next}) {
  if (character == ' ' ||
      character == '\n' ||
      character == '\t' ||
      character == '\r' ||
      character == '　') {
    return true;
  }
  const marks = '、。，,！!？?・…';
  if (marks.contains(character)) {
    return true;
  }
  if (character == '.' || character == '．') {
    final before = int.tryParse(previous) != null;
    final after = int.tryParse(next) != null;
    return !(before && after);
  }
  return false;
}

bool _isFiller(String token) {
  return _fillerKeys.contains(_fillerKey(token));
}

String _fillerKey(String token) {
  final folded = token
      .replaceAll('ぁ', 'あ')
      .replaceAll('ぃ', 'い')
      .replaceAll('ぅ', 'う')
      .replaceAll('ぇ', 'え')
      .replaceAll('ぉ', 'お')
      .replaceAll('ァ', 'ア')
      .replaceAll('ィ', 'イ')
      .replaceAll('ゥ', 'ウ')
      .replaceAll('ェ', 'エ')
      .replaceAll('ォ', 'オ');
  return FoodSearchNormalizer.normalize(folded);
}

List<String> _adoptLater(List<String> tokens) {
  final kept = <String>[];
  for (final token in tokens) {
    if (kept.isNotEmpty && _laterCorrects(token, kept.last)) {
      kept[kept.length - 1] = token;
    } else {
      kept.add(token);
    }
  }
  return kept;
}

bool _laterCorrects(String later, String earlier) {
  final laterKey = FoodSearchNormalizer.normalize(later);
  final earlierKey = FoodSearchNormalizer.normalize(earlier);
  return earlierKey.isNotEmpty && laterKey.startsWith(earlierKey);
}

({int start, int value})? _japaneseNumberBefore(String text, int at) {
  var index = at;
  while (index > 0 && _isHiragana(text[index - 1])) {
    index -= 1;
  }
  final slice = text.substring(index, at);
  if (slice.isEmpty) {
    return null;
  }
  var cut = 0;
  while (cut < slice.length) {
    final part = slice.substring(cut);
    final value = _parseJapaneseNumber(part);
    if (value != null) {
      return (start: index + cut, value: value);
    }
    cut += 1;
  }
  return null;
}

bool _isHiragana(String character) {
  if (character.isEmpty) {
    return false;
  }
  final code = character.codeUnitAt(0);
  return code >= 0x3041 && code <= 0x3096;
}

int? _parseJapaneseNumber(String text) {
  if (text.isEmpty) {
    return null;
  }
  var index = 0;
  var total = 0;
  var current = 0;
  var saw = false;
  while (index < text.length) {
    final unit = _take(_numberUnits, text, index);
    if (unit != null) {
      final count = current == 0 ? 1 : current;
      total += count * unit.value;
      current = 0;
      index += unit.length;
      saw = true;
      continue;
    }
    final one = _take(_numberOnes, text, index);
    if (one == null) {
      return null;
    }
    current = one.value;
    index += one.length;
    saw = true;
  }
  if (!saw) {
    return null;
  }
  return total + current;
}

({int value, int length})? _take(Map<String, int> table, String text, int index) {
  final keys = table.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final key in keys) {
    if (text.startsWith(key, index)) {
      return (value: table[key]!, length: key.length);
    }
  }
  return null;
}
