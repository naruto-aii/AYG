class HealthSnapshot {
  const HealthSnapshot({this.activeEnergyBurnedKcal, this.weightKg});

  final double? activeEnergyBurnedKcal;
  final double? weightKg;

  static const empty = HealthSnapshot();
}
