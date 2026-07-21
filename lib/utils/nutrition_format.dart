/// EAN-13 / JAN 向けバーコード正規化（Prototype）。
String? normalizeEan13Barcode(String? raw) {
  if (raw == null) {
    return null;
  }

  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 13) {
    return digits;
  }

  return null;
}

String formatNullableNutrient(double? value, {int fractionDigits = 0}) {
  if (value == null) {
    return '--';
  }
  return value.toStringAsFixed(fractionDigits);
}
