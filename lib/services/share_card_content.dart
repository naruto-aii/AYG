import 'dart:math' as math;

import '../models/daily_summary.dart';
import '../models/weight_entry.dart';
import '../services/review_prompt.dart';
import '../services/usage_record.dart';
import 'share_links.dart';

/// 共有シートに載せるカードの種類。数値はログに残さない。
enum ShareCardKind { meal, streak, weight }

/// 書き出す画像の形。正方形と、ストーリーズ向けの縦長。
enum ShareCardFormat {
  square(360, 360),
  story(360, 640);

  const ShareCardFormat(this.width, this.height);

  final double width;
  final double height;
}

/// 体重の数字を、画像と文章の両方でどう扱うか。
enum WeightPrivacy { shown, blurred, hidden }

/// エネルギー比に直したPFC。割合の合計は100。
class ShareMacroBalance {
  const ShareMacroBalance({
    required this.protein,
    required this.fat,
    required this.carb,
  });

  final int protein;
  final int fat;
  final int carb;
}

/// 共有画像と、画像が落ちても読める文章。
class ShareCardContent {
  const ShareCardContent({
    required this.kind,
    required this.format,
    required this.dateLabel,
    required this.eyebrow,
    required this.headline,
    required this.unit,
    required this.detail,
    required this.message,
    this.extra,
    this.macros,
    this.trend,
    this.privacy = WeightPrivacy.shown,
  });

  final ShareCardKind kind;
  final ShareCardFormat format;
  final String dateLabel;
  final String eyebrow;
  final String headline;
  final String unit;
  final String detail;
  final String? extra;
  final ShareMacroBalance? macros;

  /// 体重の推移。隠すときは null。絶対値のkgは入れない。
  final List<double>? trend;
  final WeightPrivacy privacy;

  /// 共有シートの文章。URLを含む。隠した数字はここにも出さない。
  final String message;
}

({String screen, String action}) shareScreenAction(ShareCardKind kind) {
  return switch (kind) {
    ShareCardKind.meal => (
      screen: UsageScreen.home,
      action: UsageScreenAction.shareMeal,
    ),
    ShareCardKind.streak => (
      screen: UsageScreen.home,
      action: UsageScreenAction.shareStreak,
    ),
    ShareCardKind.weight => (
      screen: UsageScreen.weight,
      action: UsageScreenAction.shareWeight,
    ),
  };
}

String shareKindLabel(ShareCardKind kind) {
  return switch (kind) {
    ShareCardKind.meal => '今日のまとめ',
    ShareCardKind.streak => '連続記録',
    ShareCardKind.weight => '体重の変化',
  };
}

String formatShareCount(num value) {
  final rounded = value.round();
  final digits = rounded.abs().toString();
  final buffer = StringBuffer(rounded < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// たんぱく質4kcal/g、脂質9kcal/g、炭水化物4kcal/g。合計が0なら出さない。
ShareMacroBalance? macroEnergyBalance({
  required double proteinG,
  required double fatG,
  required double carbG,
}) {
  final parts = [
    math.max(0, proteinG) * 4,
    math.max(0, fatG) * 9,
    math.max(0, carbG) * 4,
  ];
  final total = parts.fold<double>(0, (sum, part) => sum + part);
  if (total <= 0) {
    return null;
  }
  final raw = [for (final part in parts) part / total * 100];
  final floors = [for (final value in raw) value.floor()];
  var left = 100 - floors.fold<int>(0, (sum, part) => sum + part);
  final order = [0, 1, 2]
    ..sort((a, b) {
      final byFraction = (raw[b] - floors[b]).compareTo(raw[a] - floors[a]);
      if (byFraction != 0) {
        return byFraction;
      }
      return a.compareTo(b);
    });
  for (final index in order) {
    if (left <= 0) {
      break;
    }
    floors[index] += 1;
    left -= 1;
  }
  return ShareMacroBalance(protein: floors[0], fat: floors[1], carb: floors[2]);
}

/// 今日を記録していれば今日まで、なければ昨日までの連続日数。
int recordingStreakLength(Set<DateTime> days, DateTime now) {
  final today = reviewDay(now);
  var cursor = days.contains(today)
      ? today
      : today.subtract(const Duration(days: 1));
  if (!days.contains(cursor)) {
    return 0;
  }
  var count = 0;
  while (days.contains(cursor)) {
    count += 1;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return count;
}

int currentRecordingStreakDays({
  required Iterable<DateTime> foodLoggedAts,
  required Iterable<DateTime> exerciseLoggedAts,
  required Iterable<DateTime> alcoholConsumedAts,
  required Iterable<WeightEntry> weightEntries,
  required DateTime now,
}) {
  return recordingStreakLength(
    reviewLoggedDays(
      foodLoggedAts: foodLoggedAts,
      exerciseLoggedAts: exerciseLoggedAts,
      alcoholConsumedAts: alcoholConsumedAts,
      weightEntries: weightEntries,
    ),
    now,
  );
}

ShareCardContent buildMealShareCard({
  required DailySummary summary,
  required DateTime day,
  required ShareCardFormat format,
}) {
  final macros = macroEnergyBalance(
    proteinG: summary.intakeProteinG,
    fatG: summary.intakeFatG,
    carbG: summary.intakeCarbG,
  );
  final intake = formatShareCount(summary.intakeKcal);
  final quietDay =
      summary.intakeKcal.round() == 0 && summary.exerciseBurnKcal.round() == 0;
  final String detail;
  if (summary.isCalorieOverage) {
    detail = '目標を ${formatShareCount(summary.calorieOverageKcal)}kcal 超えています';
  } else if (quietDay) {
    detail = 'まだ記録がありません';
  } else if (summary.remainingKcal.round() == 0) {
    detail = '目標ちょうどです';
  } else {
    detail = '目標まであと ${formatShareCount(summary.remainingKcal)}kcal';
  }
  final extra = summary.exerciseBurnKcal.round() > 0
      ? '運動で ${formatShareCount(summary.exerciseBurnKcal)}kcal'
      : null;
  return ShareCardContent(
    kind: ShareCardKind.meal,
    format: format,
    dateLabel: _dateLabel(day),
    eyebrow: '今日の食事',
    headline: intake,
    unit: 'kcal',
    detail: detail,
    extra: extra,
    macros: macros,
    message: _mealMessage(
      summary: summary,
      intake: intake,
      quietDay: quietDay,
      macros: macros,
    ),
  );
}

ShareCardContent buildStreakShareCard({
  required int days,
  required DateTime day,
  required ShareCardFormat format,
}) {
  final safeDays = days < 0 ? 0 : days;
  final detail = safeDays == 0 ? '今日の記録から始まります' : '続けて記録しています';
  final lead = safeDays == 0
      ? 'カロナビで、記録を始めています。'
      : 'カロナビで、$safeDays日連続で記録しています。';
  return ShareCardContent(
    kind: ShareCardKind.streak,
    format: format,
    dateLabel: _dateLabel(day),
    eyebrow: '連続記録',
    headline: '$safeDays',
    unit: '日',
    detail: detail,
    message: '$lead\n食事・運動・体重を、まとめて残すアプリです。\n$shareDownloadUrl',
  );
}

ShareCardContent buildWeightShareCard({
  required String periodLabel,
  required List<double> weightsKg,
  required WeightPrivacy privacy,
  required DateTime day,
  required ShareCardFormat format,
}) {
  if (weightsKg.length < 2) {
    return ShareCardContent(
      kind: ShareCardKind.weight,
      format: format,
      dateLabel: _dateLabel(day),
      eyebrow: '体重の変化',
      headline: '—',
      unit: '',
      detail: '2回以上記録すると、変化を送れます',
      privacy: WeightPrivacy.hidden,
      message: '体重の変化は、2回以上記録すると共有できます。\n$shareDownloadUrl',
    );
  }
  final delta = weightsKg.last - weightsKg.first;
  final amount = delta.abs().toStringAsFixed(1);
  final flat = delta.abs() < 0.05;
  final String shownDetail;
  final String shownLead;
  if (flat) {
    shownDetail = '$periodLabelは、ほぼ同じです';
    shownLead = 'この$periodLabelは、体重がほぼ変わっていません。';
  } else if (delta < 0) {
    shownDetail = '$periodLabelで減りました';
    shownLead = 'この$periodLabelで、体重が${amount}kg減りました。';
  } else {
    shownDetail = '$periodLabelで増えました';
    shownLead = 'この$periodLabelで、体重が${amount}kg増えました。';
  }
  final String headline;
  final String unit;
  final String detail;
  final String lead;
  final List<double>? trend;
  switch (privacy) {
    case WeightPrivacy.shown:
      headline = amount;
      unit = 'kg';
      detail = shownDetail;
      lead = shownLead;
      trend = weightsKg;
    case WeightPrivacy.blurred:
      headline = amount;
      unit = 'kg';
      detail = '数字はぼかしています';
      lead = '体重の数字はぼかして、変化の記録を共有しています。';
      trend = weightsKg;
    case WeightPrivacy.hidden:
      headline = '非公開';
      unit = '';
      detail = '数字は出していません';
      lead = '体重の数字は出さずに、変化の記録を共有しています。';
      trend = null;
  }
  return ShareCardContent(
    kind: ShareCardKind.weight,
    format: format,
    dateLabel: _dateLabel(day),
    eyebrow: '体重の変化',
    headline: headline,
    unit: unit,
    detail: detail,
    trend: trend,
    privacy: privacy,
    message: '$lead\n今の体重そのものは書いていません。\nカロナビは、iPhoneのアプリです。\n$shareDownloadUrl',
  );
}

String _dateLabel(DateTime day) {
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  final weekday = weekdays[day.weekday - 1];
  return '${day.year}年${day.month}月${day.day}日（$weekday）';
}

String _mealMessage({
  required DailySummary summary,
  required String intake,
  required bool quietDay,
  required ShareMacroBalance? macros,
}) {
  final lines = <String>[];
  if (summary.isCalorieOverage) {
    lines.add(
      '今日の食事は$intake kcalで、目標を${formatShareCount(summary.calorieOverageKcal)}kcal超えています。',
    );
  } else if (quietDay) {
    lines.add(
      '今日の食事は、まだ記録がありません。目標まであと${formatShareCount(summary.remainingKcal)}kcalです。',
    );
  } else if (summary.remainingKcal.round() == 0) {
    lines.add('今日の食事は$intake kcalで、目標ちょうどです。');
  } else {
    lines.add(
      '今日の食事は$intake kcalで、目標まであと${formatShareCount(summary.remainingKcal)}kcalです。',
    );
  }
  if (summary.exerciseBurnKcal.round() > 0) {
    lines.add('運動で${formatShareCount(summary.exerciseBurnKcal)}kcal使いました。');
  }
  if (macros != null) {
    lines.add(
      'たんぱく質${macros.protein}%、脂質${macros.fat}%、炭水化物${macros.carb}%です。',
    );
  }
  lines.add('カロナビは、iPhoneのアプリです。');
  lines.add(shareDownloadUrl);
  return lines.join('\n');
}
