/// 完全一致・前方一致・部分一致が無いときの言い間違い。
///
/// 3文字未満はゆらさない。「ささ」で「ささみ」を採らない。
/// 距離1を優先し、5文字以上だけ距離2を許す。
abstract final class FoodSearchFuzzy {
  /// ゆらぎとして採用する編集距離。該当しなければ null。
  static int? distance(String haystack, String needle) {
    if (haystack.isEmpty || needle.isEmpty) {
      return null;
    }
    final needleLength = needle.runes.length;
    final haystackLength = haystack.runes.length;
    if (needleLength < 3 || needleLength > 16) {
      return null;
    }
    final gap = (haystackLength - needleLength).abs();
    if (gap > 2) {
      return null;
    }
    final distance = _levenshtein(haystack, needle);
    if (distance <= 0 || distance > 2) {
      return null;
    }
    if (distance == 1) {
      return 1;
    }
    if (needleLength >= 5 && _trigramSimilarity(haystack, needle) >= 0.34) {
      return 2;
    }
    return null;
  }

  static int _levenshtein(String a, String b) {
    final left = a.runes.toList();
    final right = b.runes.toList();
    if (left.isEmpty) {
      return right.length;
    }
    if (right.isEmpty) {
      return left.length;
    }
    var previous = List<int>.generate(right.length + 1, (index) => index);
    for (var i = 0; i < left.length; i++) {
      final current = List<int>.filled(right.length + 1, 0);
      current[0] = i + 1;
      for (var j = 0; j < right.length; j++) {
        final cost = left[i] == right[j] ? 0 : 1;
        final insert = current[j] + 1;
        final delete = previous[j + 1] + 1;
        final replace = previous[j] + cost;
        var best = insert < delete ? insert : delete;
        if (replace < best) {
          best = replace;
        }
        current[j + 1] = best;
      }
      previous = current;
    }
    return previous[right.length];
  }

  /// pg_trgm と同じ、前後を空白で埋めたトライグラムの Jaccard。
  static double _trigramSimilarity(String a, String b) {
    final left = _trigrams(a);
    final right = _trigrams(b);
    if (left.isEmpty || right.isEmpty) {
      return 0;
    }
    var shared = 0;
    final seen = <String, int>{};
    for (final gram in left) {
      seen[gram] = (seen[gram] ?? 0) + 1;
    }
    for (final gram in right) {
      final count = seen[gram] ?? 0;
      if (count > 0) {
        shared += 1;
        seen[gram] = count - 1;
      }
    }
    final union = left.length + right.length - shared;
    if (union <= 0) {
      return 0;
    }
    return shared / union;
  }

  static List<String> _trigrams(String text) {
    final padded = '  $text ';
    final grams = <String>[];
    final runes = padded.runes.toList();
    for (var i = 0; i + 2 < runes.length; i++) {
      grams.add(String.fromCharCodes(runes.sublist(i, i + 3)));
    }
    return grams;
  }
}
