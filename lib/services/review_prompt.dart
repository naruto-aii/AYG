import '../models/health_profile_data.dart';
import '../models/weight_entry.dart';

/// レビューを出すきっかけ。食事・運動・体重・アルコールのどれでも、記録なら数える。
const reviewPromptStreakDays = 7;

enum ReviewRecordOrigin { app, widget, siri }

DateTime reviewDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

/// 手入力の体重だけを記録に数える。ヘルスケアの自動取得は含めない。
Set<DateTime> reviewLoggedDays({
  required Iterable<DateTime> foodLoggedAts,
  required Iterable<DateTime> exerciseLoggedAts,
  required Iterable<DateTime> alcoholConsumedAts,
  required Iterable<WeightEntry> weightEntries,
}) {
  return {
    for (final loggedAt in foodLoggedAts) reviewDay(loggedAt),
    for (final loggedAt in exerciseLoggedAts) reviewDay(loggedAt),
    for (final consumedAt in alcoholConsumedAts) reviewDay(consumedAt),
    for (final entry in weightEntries)
      if (entry.source == WeightSource.manual) reviewDay(entry.recordedAt),
  };
}

bool reviewCoversStreak(
  Set<DateTime> days,
  DateTime now, {
  int length = reviewPromptStreakDays,
}) {
  if (length <= 0) {
    return false;
  }
  final today = reviewDay(now);
  for (var offset = 0; offset < length; offset++) {
    if (!days.contains(today.subtract(Duration(days: offset)))) {
      return false;
    }
  }
  return true;
}

/// この記録で、今日を含む連続日数が初めて揃ったときだけ true。
bool reviewStreakJustCompleted({
  required Set<DateTime> daysBefore,
  required Set<DateTime> daysAfter,
  required DateTime now,
  int length = reviewPromptStreakDays,
}) {
  return !reviewCoversStreak(daysBefore, now, length: length) &&
      reviewCoversStreak(daysAfter, now, length: length);
}

bool reviewOriginIsExternal(ReviewRecordOrigin origin) {
  return origin == ReviewRecordOrigin.widget ||
      origin == ReviewRecordOrigin.siri;
}
