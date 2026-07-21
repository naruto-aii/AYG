enum ActivityLevel {
  low('Low', 1.2),
  light('Light', 1.375),
  moderate('Moderate', 1.55),
  high('High', 1.725),
  veryHigh('Very High', 1.9);

  const ActivityLevel(this.label, this.factor);

  final String label;
  final double factor;
}
