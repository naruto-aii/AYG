import 'dart:math' as math;

import '../constants/app_strings.dart';
import '../models/daily_summary.dart';
import 'share_links.dart';

/// 共有画像の一辺。正方形だけ。
const shareCardSize = 360.0;

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

/// 今日のまとめの画像と、画像が落ちても読める文章。
class ShareCardContent {
  const ShareCardContent({
    required this.dateLabel,
    required this.eyebrow,
    required this.headline,
    required this.unit,
    required this.detail,
    required this.message,
    this.macros,
  });

  final String dateLabel;
  final String eyebrow;
  final String headline;
  final String unit;
  final String detail;
  final ShareMacroBalance? macros;

  /// 共有シートの文章。摂取、目標との差、PFC、紹介文、URL。
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

ShareCardContent buildMealShareCard({
  required DailySummary summary,
  required DateTime day,
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
  return ShareCardContent(
    dateLabel: _dateLabel(day),
    eyebrow: '今日の食事',
    headline: intake,
    unit: 'kcal',
    detail: detail,
    macros: macros,
    message: _mealMessage(
      summary: summary,
      intake: intake,
      quietDay: quietDay,
      macros: macros,
    ),
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
  if (macros != null) {
    lines.add(
      'たんぱく質${macros.protein}%、脂質${macros.fat}%、炭水化物${macros.carb}%です。',
    );
  }
  lines.add(AppStrings.loginTagline);
  lines.add(shareDownloadUrl);
  return lines.join('\n');
}
