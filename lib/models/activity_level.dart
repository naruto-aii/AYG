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
