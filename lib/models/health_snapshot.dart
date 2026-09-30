class HealthSnapshot {
  const HealthSnapshot({
    this.activeEnergyBurnedKcal,
    this.weightKg,
    this.weightMeasuredAt,
  });

  final double? activeEnergyBurnedKcal;
  final double? weightKg;

  /// Health の体重サンプルの測定時刻。同期した時刻ではない。
  final DateTime? weightMeasuredAt;

  static const empty = HealthSnapshot();
}
