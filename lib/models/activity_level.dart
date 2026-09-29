enum ActivityLevel {
  low('低い', 1.2),
  light('やや低い', 1.375),
  moderate('普通', 1.55),
  high('高い', 1.725),
  veryHigh('非常に高い', 1.9);

  const ActivityLevel(this.label, this.factor);

  final String label;
  final double factor;
}

/// 日常語ラベル（ActivityLevel の表示用拡張）。
extension ActivityLevelEverydayX on ActivityLevel {
  String get everydayLabel => switch (this) {
    ActivityLevel.low => '座っている時間が長い',
    ActivityLevel.light => '立ち仕事・歩くことが少し多い',
    ActivityLevel.moderate => '日常的によく動く',
    ActivityLevel.high => 'かなり活動的',
    ActivityLevel.veryHigh => '非常に活動的',
  };

  String get everydayDescription => switch (this) {
    ActivityLevel.low => 'デスクワーク中心で、日中の歩行が少ない',
    ActivityLevel.light => '通勤や家事で軽い移動がある',
    ActivityLevel.moderate => '立ち仕事や徒歩移動が日常にある',
    ActivityLevel.high => '日中の移動や立ち仕事が多い',
    ActivityLevel.veryHigh => '肉体労働や終日の移動が多い',
  };
}
