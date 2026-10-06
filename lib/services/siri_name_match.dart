import '../utils/food_search_normalizer.dart';

/// Siri の名寄せ。順位はアプリ内の `search_official_foods` / [OfficialFoodRanker] と同じ。
///
/// 完全一致、前方一致、部分一致の順。確定した別名は、同じ段の候補より前。
/// いちばん上が次より明らかに良いときだけ採用し、同じ段が続くときは上位数件を選ばせる。
const int siriChoiceLimit = 4;

/// 前方一致・部分一致に進む最短の文字数。2文字の「ささ」では候補を作らない。
const int siriFuzzyMinLength = 3;

class SiriMatchHit {
  const SiriMatchHit({
    required this.id,
    required this.speakName,
    required this.matchRank,
    this.isCandidate = false,
    this.candidateRank = 100,
    this.priority = 100,
    this.aliasMatched = false,
  });

  final String id;
  final String speakName;
  final int matchRank;
  final bool isCandidate;
  final int candidateRank;
  final int priority;
  final bool aliasMatched;
}

enum SiriMatchDecision { one, choices, none }

class SiriMatchResult {
  const SiriMatchResult(this.decision, this.hits);

  final SiriMatchDecision decision;
  final List<SiriMatchHit> hits;

  static const none = SiriMatchResult(SiriMatchDecision.none, []);
}

/// 検索語のゆれ。空白と長音は [FoodSearchNormalizer] が除く。
/// 「を」「の」が間に入った言い方も、除いた形で照合する。
List<String> siriQueryVariants(String raw) {
  final primary = FoodSearchNormalizer.normalize(raw);
  if (primary.isEmpty) {
    return const [];
  }
  final stripped = primary.replaceAll(RegExp('[をのはがにとでも]'), '');
  if (stripped.isEmpty || stripped == primary) {
    return [primary];
  }
  return [primary, stripped];
}

/// `OfficialFoodRanker` の段。0 完全一致、1 前方一致、2 部分一致、9 不一致。
int siriTextRank(String haystack, String needle) {
  if (haystack.isEmpty || needle.isEmpty) {
    return 9;
  }
  if (haystack == needle) {
    return 0;
  }
  if (needle.length < siriFuzzyMinLength) {
    return 9;
  }
  final at = haystack.indexOf(needle);
  if (at == 0) {
    return 1;
  }
  if (at > 0) {
    return 2;
  }
  return 9;
}

int compareSiriHits(SiriMatchHit a, SiriMatchHit b) {
  final rank = a.matchRank.compareTo(b.matchRank);
  if (rank != 0) {
    return rank;
  }
  final candidate = (a.isCandidate ? 1 : 0).compareTo(b.isCandidate ? 1 : 0);
  if (candidate != 0) {
    return candidate;
  }
  final candidateRank = a.candidateRank.compareTo(b.candidateRank);
  if (candidateRank != 0) {
    return candidateRank;
  }
  final alias = (a.aliasMatched ? 0 : 1).compareTo(b.aliasMatched ? 0 : 1);
  if (alias != 0) {
    return alias;
  }
  final priority = a.priority.compareTo(b.priority);
  if (priority != 0) {
    return priority;
  }
  return a.id.compareTo(b.id);
}

/// 並んだ候補から、採用・選ばせ・なしを決める。
SiriMatchResult pickSiriMatches(List<SiriMatchHit> hits) {
  if (hits.isEmpty) {
    return SiriMatchResult.none;
  }
  final sorted = [...hits]..sort(compareSiriHits);
  final best = <String, SiriMatchHit>{};
  for (final hit in sorted) {
    best.putIfAbsent(hit.id, () => hit);
  }
  final unique = best.values.toList()..sort(compareSiriHits);
  if (unique.length == 1 || _isObvious(unique.first, unique[1])) {
    return SiriMatchResult(SiriMatchDecision.one, [unique.first]);
  }
  final limit = unique.length < siriChoiceLimit
      ? unique.length
      : siriChoiceLimit;
  return SiriMatchResult(
    SiriMatchDecision.choices,
    unique.sublist(0, limit),
  );
}

bool _isObvious(SiriMatchHit top, SiriMatchHit next) {
  if (top.matchRank < next.matchRank) {
    return true;
  }
  return !top.isCandidate && next.isCandidate && top.matchRank == next.matchRank;
}

/// 話し言葉で、代表の種目に決めてよい呼び方。キーは正規化後。
///
/// 同じ語が別名にも付いているときは、こちらを優先する。
/// 「散歩」は犬の散歩の別名でもあるが、何も付けずに言ったときはウォーキング。
const Map<String, String> spokenExerciseActivityIds = {
  'さんぽ': 'walk_brisk',
  '散歩': 'walk_brisk',
  'うぉきんぐ': 'walk_brisk',
  'うぉく': 'walk_brisk',
  '歩き': 'walk_brisk',
  'あるき': 'walk_brisk',
  '歩く': 'walk_brisk',
  'あるく': 'walk_brisk',
  'じょぎんぐ': 'jogging',
  'じょぐ': 'jogging',
  'らんにんぐ': 'running',
  'らん': 'running',
  '走り': 'running',
  'はしり': 'running',
  '筋トレ': 'weight_training',
  'きんとれ': 'weight_training',
  '自転車': 'cycle_road',
  'じてんしゃ': 'cycle_road',
  'ちゃり': 'cycle_road',
};

String? spokenExerciseActivityId(String raw) {
  for (final variant in siriQueryVariants(raw)) {
    final id = spokenExerciseActivityIds[variant];
    if (id != null) {
      return id;
    }
  }
  return null;
}

/// g や分に決まらない量。数字だけの答えを、あとから聞き返す。
class SiriVagueQuantity {
  const SiriVagueQuantity(this.label);

  final String label;
}

const _vagueAmountWords = [
  '大盛り',
  'おおもり',
  '大盛',
  '少なめ',
  'すくなめ',
  '半分',
  'はんぶん',
  '普通',
  'ふつう',
  '多め',
  'おおめ',
  '一杯',
  'いっぱい',
  'カップ',
  'かっぷ',
  'パック',
  'ぱっく',
  '袋',
  '皿',
  'さら',
  '杯',
  '膳',
  '人前',
  'ちょっと',
  '少し',
  'すこし',
  '軽く',
  'かるく',
  'した',
  'しました',
  'やった',
  'やって',
];

SiriVagueQuantity? parseSiriVagueQuantity(String raw) {
  var compact = raw
      .trim()
      .replaceAll(' ', '')
      .replaceAll('　', '')
      .replaceFirst(RegExp(r'[。．.！!？?]+$'), '');
  if (compact.isEmpty) {
    return null;
  }
  final numbered = RegExp(r'^(\d+(?:\.\d+)?)(.+)$').firstMatch(compact);
  if (numbered != null) {
    final word = numbered.group(2)!;
    if (_vagueAmountWords.contains(word)) {
      return SiriVagueQuantity(compact);
    }
    return null;
  }
  if (_vagueAmountWords.contains(compact)) {
    return SiriVagueQuantity(compact);
  }
  return null;
}

/// 文末の曖昧な量を食品名から分ける。「ご飯大盛り」「納豆1パック」「散歩した」。
({String name, String vague})? splitSiriVagueTail(String raw) {
  var compact = raw
      .trim()
      .replaceAll(' ', '')
      .replaceAll('　', '')
      .replaceFirst(RegExp(r'[。．.！!？?]+$'), '');
  if (compact.isEmpty) {
    return null;
  }
  final words = [..._vagueAmountWords]..sort((a, b) => b.length.compareTo(a.length));
  for (final word in words) {
    final numbered = RegExp('(\\d+(?:\\.\\d+)?)${RegExp.escape(word)}\$');
    final found = numbered.firstMatch(compact);
    if (found != null && found.start > 0) {
      return (
        name: compact.substring(0, found.start),
        vague: compact.substring(found.start),
      );
    }
    if (compact.endsWith(word) && compact.length > word.length) {
      return (
        name: compact.substring(0, compact.length - word.length),
        vague: word,
      );
    }
  }
  return null;
}
