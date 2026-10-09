import 'package:health/health.dart';

import '../models/user_profile.dart';

/// HealthKit の性別（HKBiologicalSex）を読む。
///
/// health パッケージは性別を文字ではなく数値で返す
/// （0: 未設定 / 1: 女性 / 2: 男性 / 3: その他）。
/// 未設定や読めない値は null にして、利用者に選んでもらう。
Gender? genderFromHealthValue(HealthValue value) {
  if (value is! NumericHealthValue) {
    return null;
  }
  return switch (value.numericValue.round()) {
    1 => Gender.female,
    2 => Gender.male,
    3 => Gender.other,
    _ => null,
  };
}

/// HealthKit の生年月日を読む。
///
/// health パッケージは生年月日を値（1970年からの秒）で返す。
/// 点の dateFrom は問い合わせの開始日なので使わない。
/// 未設定は 0 で届くので null にする。
DateTime? birthDateFromHealthValue(HealthValue value) {
  if (value is! NumericHealthValue) {
    return null;
  }
  final seconds = value.numericValue;
  if (seconds == 0) {
    return null;
  }
  final date = DateTime.fromMillisecondsSinceEpoch((seconds * 1000).round());
  final now = DateTime.now();
  if (date.isAfter(now) || date.year < 1900) {
    return null;
  }
  return DateTime(date.year, date.month, date.day);
}
