/// EAN-13 / JAN / UPC 向けバーコード正規化。
String? normalizeEan13Barcode(String? raw) {
  if (raw == null) {
    return null;
  }

  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 13) {
    return digits;
  }
  if (digits.length == 12) {
    return '0$digits';
  }
  if (digits.length == 8) {
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
