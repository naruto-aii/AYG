import '../models/activity_level.dart';

/// 普段の生活活動係数（別途記録する運動は含まない）。
class LifestyleActivityCatalog {
  LifestyleActivityCatalog._();

  static const productNote =
      '生活活動係数はカロナビのプロダクト既定値です。'
      '別途アプリに記録した運動は含みません。';

  static const entries = <LifestyleActivityEntry>[
    LifestyleActivityEntry(
      level: ActivityLevel.low,
      everydayLabel: '座っている時間が長い',
      description: 'デスクワーク中心で、日中の歩行が少ない',
      factor: 1.2,
      referenceNote: 'PAL 1.2 相当（プロダクト既定）',
    ),
    LifestyleActivityEntry(
      level: ActivityLevel.light,
      everydayLabel: '立ち仕事・歩くことが少し多い',
      description: '通勤や家事で軽い移動がある',
      factor: 1.375,
      referenceNote: 'PAL 1.375 相当（プロダクト既定）',
    ),
    LifestyleActivityEntry(
      level: ActivityLevel.moderate,
      everydayLabel: '日常的によく動く',
      description: '立ち仕事や徒歩移動が日常にある',
      factor: 1.55,
      referenceNote: 'PAL 1.55 相当（プロダクト既定）',
    ),
    LifestyleActivityEntry(
      level: ActivityLevel.high,
      everydayLabel: 'かなり活動的',
      description: '日中の移動や立ち仕事が多い',
      factor: 1.725,
      referenceNote: 'PAL 1.725 相当（プロダクト既定）',
    ),
    LifestyleActivityEntry(
      level: ActivityLevel.veryHigh,
      everydayLabel: '非常に活動的',
      description: '肉体労働や終日の移動が多い',
      factor: 1.9,
      referenceNote: 'PAL 1.9 相当（プロダクト既定）',
    ),
  ];

  static LifestyleActivityEntry forLevel(ActivityLevel level) {
    return entries.firstWhere((entry) => entry.level == level);
  }

  static double factorFor(ActivityLevel level) => forLevel(level).factor;

  static String everydayLabelFor(ActivityLevel level) =>
      forLevel(level).everydayLabel;
}

class LifestyleActivityEntry {
  const LifestyleActivityEntry({
    required this.level,
    required this.everydayLabel,
    required this.description,
    required this.factor,
    required this.referenceNote,
  });

  final ActivityLevel level;
  final String everydayLabel;
  final String description;
  final double factor;
  final String referenceNote;
}
