/// 記録時刻の読み書き。
///
/// 旧アプリは日本などの壁時計をオフセット無しで送り、`timestamptz` は
/// その数字を UTC として保存した。新しい記録は本当の UTC に、
/// ミリ秒 0・マイクロ秒 1 の印を付けて送る。印が無い UTC は旧行として、
/// 暦の数字をそのまま壁時計に読む。印がある UTC だけ [DateTime.toLocal] する。
///
/// 端末内に残っているローカルの [DateTime]（まだサーバーの形になっていない旧記録）は
/// 壁時計の数字のまま UTC として送る。ここで [DateTime.toUtc] すると約9時間ずれ、
/// 既存の行を書き換える。
const int absoluteRecordMicrosecond = 1;

/// 新規のローカル壁時計を新形式にする。すでに UTC の値はいじらない。
///
/// 旧行の UTC に印を付け直すと、表示が [DateTime.toLocal] に切り替わって
/// 日付がずれる。ローカルのまま残っている旧行も、ここを通さない。
DateTime asNewRecordInstant(DateTime value) {
  if (value.isUtc) {
    return value;
  }
  return stampRecordInstant(value);
}

/// 新しい記録の瞬間。表示は [civilClock]、送信は [encodeRecordTimestamp]。
DateTime stampRecordInstant(DateTime value) {
  final utc = value.toUtc();
  return DateTime.utc(
    utc.year,
    utc.month,
    utc.day,
    utc.hour,
    utc.minute,
    utc.second,
    0,
    absoluteRecordMicrosecond,
  );
}

/// 新形式の UTC か。旧行の `DateTime.now()` が偶然この印になる確率は約100万分の1。
bool isAbsoluteRecordInstant(DateTime value) {
  return value.isUtc &&
      value.millisecond == 0 &&
      value.microsecond == absoluteRecordMicrosecond;
}

/// 画面と日付のまとめに使う壁時計。
///
/// 新形式は [DateTime.toLocal]。旧形式の UTC は暦の数字をローカルの
/// [DateTime] に写す（もう一度 [DateTime.toLocal] しない）。
/// すでにローカルならそのまま。
DateTime civilClock(DateTime value) {
  if (!value.isUtc) {
    return value;
  }
  if (isAbsoluteRecordInstant(value)) {
    return value.toLocal();
  }
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

/// サーバーへ送る ISO 文字列。UTC には `Z` が付く。
///
/// 新形式と、読み戻した旧 UTC は同じ瞬間を送る。ローカルの旧値は
/// 壁時計の数字を UTC として送る（既存行をずらさない）。
String encodeRecordTimestamp(DateTime value) {
  return encodeRecordInstant(value).toUtc().toIso8601String();
}

/// [encodeRecordTimestamp] の瞬間。テストが往復の同一性を見るために使う。
///
/// 端末内の DB は UTC かどうかを残さない。新形式は読み戻すと
/// ローカルの壁時計に印（ミリ秒 0・マイクロ秒 1）だけが残る。
/// その値は [DateTime.toUtc] して本当の UTC に戻す。
/// 印の無いローカルは旧記録なので、壁時計の数字のまま送る。
DateTime encodeRecordInstant(DateTime value) {
  if (value.isUtc || _hasAbsoluteMark(value)) {
    return value.toUtc();
  }
  return DateTime.utc(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

bool _hasAbsoluteMark(DateTime value) {
  return value.millisecond == 0 &&
      value.microsecond == absoluteRecordMicrosecond;
}

/// 端末 DB に書く直前の値。
///
/// 旧 UTC（暦の数字が壁時計）をそのまま書くと、読み戻しが
/// [DateTime.toLocal] になり約9時間ずれる。壁時計の数字で書く。
/// 新形式は同じ瞬間のローカルになる（印は残る）。
DateTime persistRecordInstant(DateTime value) {
  final civil = civilClock(value);
  if (!civil.isUtc) {
    return civil;
  }
  return DateTime(
    civil.year,
    civil.month,
    civil.day,
    civil.hour,
    civil.minute,
    civil.second,
    civil.millisecond,
    civil.microsecond,
  );
}

/// 端末 DB から読んだ値。印があるものは本当の UTC に戻す。
DateTime recallRecordInstant(DateTime value) {
  if (_hasAbsoluteMark(value)) {
    return value.toUtc();
  }
  if (!value.isUtc) {
    return value;
  }
  return DateTime(
    value.year,
    value.month,
    value.day,
    value.hour,
    value.minute,
    value.second,
    value.millisecond,
    value.microsecond,
  );
}

/// ユーザーが日時を選び直したとき。同じ分なら元の瞬間を残す。
DateTime adoptPickedRecordTime({
  required DateTime original,
  required DateTime pickedLocal,
}) {
  final shown = civilClock(original);
  final sameMinute =
      shown.year == pickedLocal.year &&
      shown.month == pickedLocal.month &&
      shown.day == pickedLocal.day &&
      shown.hour == pickedLocal.hour &&
      shown.minute == pickedLocal.minute;
  if (sameMinute) {
    return original;
  }
  return stampRecordInstant(pickedLocal);
}

/// `H:mm`。時はゼロ埋めしない（ホームと食事タブの既存表示）。
String formatRecordMinute(DateTime value) {
  final clock = civilClock(value);
  return '${clock.hour}:${clock.minute.toString().padLeft(2, '0')}';
}

int compareRecordInstants(DateTime a, DateTime b) {
  return civilClock(a).compareTo(civilClock(b));
}

/// 壁時計の同じ秒か。新形式の印（マイクロ秒 1）と旧形式（0）も同じ測定とみなす。
bool sameCivilSecond(DateTime a, DateTime b) {
  final left = civilClock(a);
  final right = civilClock(b);
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day &&
      left.hour == right.hour &&
      left.minute == right.minute &&
      left.second == right.second;
}
