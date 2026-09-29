/// Limits shared with `public.search_official_foods`.
abstract final class OfficialFoodLimits {
  /// Raw search text is cut to this many Unicode code points before
  /// normalization. The SQL function uses `left(..., 64)` the same way.
  static const int maxQueryLength = 64;

  static String cap(String query) {
    final units = <int>[];
    for (final rune in query.runes) {
      if (units.length == maxQueryLength) {
        return String.fromCharCodes(units);
      }
      units.add(rune);
    }
    return query;
  }
}
