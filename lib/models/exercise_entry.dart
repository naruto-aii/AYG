class ExerciseEntry {
  ExerciseEntry({
    required this.id,
    required this.name,
    required this.durationMin,
    required this.burnedKcal,
    required this.loggedAt,
  });

  final String id;
  final String name;
  final int durationMin;
  final double burnedKcal;
  final DateTime loggedAt;

  ExerciseEntry copyWith({
    String? id,
    String? name,
    int? durationMin,
    double? burnedKcal,
    DateTime? loggedAt,
  }) {
    return ExerciseEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      durationMin: durationMin ?? this.durationMin,
      burnedKcal: burnedKcal ?? this.burnedKcal,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }
}
