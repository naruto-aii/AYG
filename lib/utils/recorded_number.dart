/// 記録した数を、開いてそのまま保存しても同じ数に戻る文字列にする。
///
/// ユーザーが欄を書き換えたときだけ、その新しい文字列を保存する。
String formatRecordedNumber(double value) {
  if (!value.isFinite) {
    return value.toString();
  }
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  final own = value.toString();
  if (double.tryParse(own) == value) {
    return own;
  }
  return value
      .toStringAsFixed(10)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}
