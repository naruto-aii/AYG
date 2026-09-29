/// 減量・増量時のペース（アプリ既定値）。
enum GoalPace {
  slow('ゆっくり', '無理のないペースで、小さなカロリー差から始めます', 0.75),
  standard('標準', 'バランスの取れたペースです', 1.0);

  const GoalPace(this.labelJa, this.descriptionJa, this.adjustmentMultiplier);

  final String labelJa;
  final String descriptionJa;

  /// 目標補正 kcal/day への乗数（プロダクト既定）。
  final double adjustmentMultiplier;

  static GoalPace fromName(String? raw) {
    if (raw == null || raw.isEmpty) {
      return GoalPace.standard;
    }
    return GoalPace.values.firstWhere(
      (pace) => pace.name == raw,
      orElse: () => GoalPace.standard,
    );
  }
}
