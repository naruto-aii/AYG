import '../models/exercise_calculation_source.dart';

/// MET × 時間 × 体重から gross / net カロリーを推定する。
class ExerciseCalorieCalculator {
  const ExerciseCalorieCalculator({this.calculationVersion = 'met-v1'});

  final String calculationVersion;

  static const double restingMet = 1.0;

  ExerciseCalorieEstimate? estimate({
    required double met,
    required double weightKg,
    required int durationMinutes,
    ExerciseCalculationSource source = ExerciseCalculationSource.metEstimate,
    String? sourceKey,
  }) {
    if (!_isValidMet(met) ||
        !_isValidWeight(weightKg) ||
        !_isValidDuration(durationMinutes)) {
      return null;
    }

    final gross = _grossKcal(
      met: met,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
    );
    final net = _netKcal(
      met: met,
      weightKg: weightKg,
      durationMinutes: durationMinutes,
    );

    if (!gross.isFinite || !net.isFinite) {
      return null;
    }

    return ExerciseCalorieEstimate(
      met: met,
      weightKgSnapshot: weightKg,
      grossKcal: gross,
      netKcal: net,
      calculationSource: source,
      calculationVersion: calculationVersion,
      sourceKey: sourceKey,
    );
  }

  double _grossKcal({
    required double met,
    required double weightKg,
    required int durationMinutes,
  }) {
    return met * 3.5 * weightKg / 200 * durationMinutes;
  }

  double _netKcal({
    required double met,
    required double weightKg,
    required int durationMinutes,
  }) {
    final activityMet = met - restingMet;
    if (activityMet <= 0) {
      return 0;
    }
    return activityMet * 3.5 * weightKg / 200 * durationMinutes;
  }

  bool _isValidMet(double met) =>
      met.isFinite && met > 0 && !met.isNaN && !met.isInfinite;

  bool _isValidWeight(double weightKg) =>
      weightKg.isFinite && weightKg > 0 && !weightKg.isNaN;

  bool _isValidDuration(int durationMinutes) =>
      durationMinutes > 0 && durationMinutes < 24 * 60;
}

class ExerciseCalorieEstimate {
  const ExerciseCalorieEstimate({
    required this.met,
    required this.weightKgSnapshot,
    required this.grossKcal,
    required this.netKcal,
    required this.calculationSource,
    required this.calculationVersion,
    this.sourceKey,
  });

  final double met;
  final double weightKgSnapshot;
  final double grossKcal;
  final double netKcal;
  final ExerciseCalculationSource calculationSource;
  final String calculationVersion;
  final String? sourceKey;
}
