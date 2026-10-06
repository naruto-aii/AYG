import '../constants/app_strings.dart';
import '../models/daily_summary.dart';
import 'share_links.dart';

/// 共有画像の一辺。正方形だけ。
const shareCardSize = 360.0;

/// 今日の摂取カロリーの画像と、画像が落ちても読める文章。
class ShareCardContent {
  const ShareCardContent({
    required this.dateLabel,
    required this.eyebrow,
    required this.intakeLabel,
    required this.targetLabel,
    required this.progress,
    required this.isOverage,
    required this.message,
  });

  final String dateLabel;
  final String eyebrow;
  final String intakeLabel;
  final String targetLabel;

  /// 目標に対する進み。0.0〜1.0。超えたときは1.0。
  final double progress;
  final bool isOverage;

  /// 丸の中に出す「1,820 / 2,000」。
  String get figure => '$intakeLabel / $targetLabel';

  /// 共有シートの文章。摂取と目標、紹介文、URL。
  final String message;
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

ShareCardContent buildMealShareCard({
  required DailySummary summary,
  required DateTime day,
}) {
  final intake = formatShareCount(summary.intakeKcal);
  final target = formatShareCount(summary.targetKcal);
  final progress = summary.targetKcal > 0
      ? (summary.intakeKcal / summary.targetKcal).clamp(0.0, 1.0)
      : 0.0;
  return ShareCardContent(
    dateLabel: _dateLabel(day),
    eyebrow: '今日の摂取カロリー',
    intakeLabel: intake,
    targetLabel: target,
    progress: progress,
    isOverage: summary.isCalorieOverage,
    message: [
      '今日は目標${target}kcalのうち${intake}kcalを摂りました。',
      AppStrings.loginTagline,
      shareDownloadUrl,
    ].join('\n'),
  );
}

String _dateLabel(DateTime day) {
  const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
  final weekday = weekdays[day.weekday - 1];
  return '${day.year}年${day.month}月${day.day}日（$weekday）';
}
