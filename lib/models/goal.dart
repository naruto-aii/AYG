import 'calculation/goal_pace.dart';

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
    this.goalPace = GoalPace.standard,
  });

  final GoalType type;
  final double targetWeightKg;
  final DateTime targetDate;

  /// 減量・増量時のペース。未設定・維持時は [GoalPace.standard]。
  final GoalPace goalPace;

  Goal copyWith({
    GoalType? type,
    double? targetWeightKg,
    DateTime? targetDate,
    GoalPace? goalPace,
  }) {
    return Goal(
      type: type ?? this.type,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      targetDate: targetDate ?? this.targetDate,
      goalPace: goalPace ?? this.goalPace,
    );
  }
}
