enum GoalType {
  lose('減量'),
  maintain('維持'),
  gain('増量');

  const GoalType(this.label);
  final String label;
}

class Goal {
  Goal({
    required this.type,
    required this.targetWeightKg,
    required this.targetDate,
  });

  final GoalType type;
  final double targetWeightKg;
  final DateTime targetDate;
}
