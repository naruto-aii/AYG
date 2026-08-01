/// アルコール量の単位正規化・判定。
bool isMilliliterUnit(String rawUnit) {
  final normalized = normalizeAlcoholUnit(rawUnit);
  return normalized == 'ml' || normalized == 'ミリリットル';
}

String normalizeAlcoholUnit(String rawUnit) {
  var unit = rawUnit.trim();
  if (unit.isEmpty) {
    return unit;
  }

  // 全角英字 → 半角
  final buffer = StringBuffer();
  for (final codeUnit in unit.codeUnits) {
    if (codeUnit >= 0xFF01 && codeUnit <= 0xFF5E) {
      buffer.writeCharCode(codeUnit - 0xFEE0);
    } else {
      buffer.writeCharCode(codeUnit);
    }
  }
  unit = buffer.toString();

  if (unit.toLowerCase() == 'ml') {
    return 'ml';
  }
  if (unit == 'ミリリットル') {
    return 'ミリリットル';
  }
  return unit;
}
