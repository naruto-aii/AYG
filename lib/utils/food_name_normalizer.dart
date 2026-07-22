/// 食品名の正規化（検索・重複判定用）。
class FoodNameNormalizer {
  const FoodNameNormalizer._();

  static String normalize(String raw) {
    final trimmed = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.toLowerCase();
  }
}
