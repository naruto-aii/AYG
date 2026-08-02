import 'exercise_calculation_source.dart';
import 'exercise_category.dart';

class ExerciseEntry {
  ExerciseEntry({
    required this.id,
    required this.name,
    required this.durationMin,
    required this.burnedKcal,
    required this.loggedAt,
    this.category,
    this.activityId,
    this.intensity,
    this.sets,
    this.reps,
    this.liftWeightKg,
    this.metValue,
    this.grossKcal,
    this.netKcal,
    this.weightKgSnapshot,
    this.calculationSource,
    this.calculationVersion,
    this.sourceKey,
    this.notes,
  });

  final String id;
  final String name;
  final int durationMin;

  /// 表示用の消費カロリー（gross または手入力値）。
  final double burnedKcal;
  final DateTime loggedAt;

  final ExerciseCategory? category;
  final String? activityId;
  final String? intensity;
  final int? sets;
  final int? reps;
  final double? liftWeightKg;
  final double? metValue;
  final double? grossKcal;
  final double? netKcal;
  final double? weightKgSnapshot;
  final ExerciseCalculationSource? calculationSource;
  final String? calculationVersion;
  final String? sourceKey;
  final String? notes;

  /// 残りカロリー計算に使う net。未設定の既存記録は burnedKcal を net 相当として扱う。
  double get effectiveNetKcal {
    if (netKcal != null && netKcal!.isFinite && netKcal! >= 0) {
      return netKcal!;
    }
    if (grossKcal != null &&
        metValue != null &&
        metValue! > 0 &&
        grossKcal!.isFinite) {
      final activityMet = metValue! - 1.0;
      if (activityMet <= 0) {
        return 0;
      }
      return grossKcal! * activityMet / metValue!;
    }
    return burnedKcal;
  }

  /// 詳細表示用 gross。
  double get effectiveGrossKcal {
    if (grossKcal != null && grossKcal!.isFinite) {
      return grossKcal!;
    }
    return burnedKcal;
  }

  ExerciseEntry copyWith({
    String? id,
    String? name,
    int? durationMin,
    double? burnedKcal,
    DateTime? loggedAt,
    ExerciseCategory? category,
    String? activityId,
    String? intensity,
    int? sets,
    int? reps,
    double? liftWeightKg,
    double? metValue,
    double? grossKcal,
    double? netKcal,
    double? weightKgSnapshot,
    ExerciseCalculationSource? calculationSource,
    String? calculationVersion,
    String? sourceKey,
    String? notes,
  }) {
    return ExerciseEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      durationMin: durationMin ?? this.durationMin,
      burnedKcal: burnedKcal ?? this.burnedKcal,
      loggedAt: loggedAt ?? this.loggedAt,
      category: category ?? this.category,
      activityId: activityId ?? this.activityId,
      intensity: intensity ?? this.intensity,
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      liftWeightKg: liftWeightKg ?? this.liftWeightKg,
      metValue: metValue ?? this.metValue,
      grossKcal: grossKcal ?? this.grossKcal,
      netKcal: netKcal ?? this.netKcal,
      weightKgSnapshot: weightKgSnapshot ?? this.weightKgSnapshot,
      calculationSource: calculationSource ?? this.calculationSource,
      calculationVersion: calculationVersion ?? this.calculationVersion,
      sourceKey: sourceKey ?? this.sourceKey,
      notes: notes ?? this.notes,
    );
  }
}
