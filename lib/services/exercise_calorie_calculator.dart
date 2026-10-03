import '../models/calculation/calculation_versions.dart';
import '../models/exercise_calculation_source.dart';

/// MET × 時間 × 体重から gross / net カロリーを推定する。
class ExerciseCalorieCalculator {
  const ExerciseCalorieCalculator({this.calculationVersion = 'met-v1'});

  final String calculationVersion;

  static const double restingMet = 1.0;

  /// 挙上2秒・下降2秒。ACSM の処方でよく使う 1〜2秒ずつ、の上限。
  /// セット間の休憩は含まない。
  static const int secondsPerRep = 4;

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

  /// 平地の歩行・走行。安静分を含まない kcal = 係数 × 体重kg × 距離km。
  ///
  /// 歩行 0.5、走行・ジョギング 1.0。ACSM の水平成分
  /// （歩行 0.1 mL·kg⁻¹·m⁻¹、走行 0.2 mL·kg⁻¹·m⁻¹）を
  /// 1 L の酸素 ≈ 5 kcal で 1 km に直した値。
  ExerciseCalorieEstimate? estimateByDistanceFactor({
    required double weightKg,
    required double distanceKm,
    required double netKcalPerKgKm,
    String? sourceKey,
  }) {
    if (!_isValidWeight(weightKg) ||
        !_isValidDistance(distanceKm) ||
        !netKcalPerKgKm.isFinite ||
        netKcalPerKgKm <= 0) {
      return null;
    }
    final net = netKcalPerKgKm * weightKg * distanceKm;
    if (!net.isFinite) {
      return null;
    }
    return ExerciseCalorieEstimate(
      met: netKcalPerKgKm,
      weightKgSnapshot: weightKg,
      grossKcal: net,
      netKcal: net,
      calculationSource: ExerciseCalculationSource.metEstimate,
      calculationVersion: CalculationVersions.exerciseDistance,
      sourceKey: sourceKey,
    );
  }

  /// 距離を、出典に書いてある速度で分に直してから [estimate] と同じ MET 式。
  ExerciseCalorieEstimate? estimateByDistanceSpeed({
    required double met,
    required double weightKg,
    required double distanceKm,
    required double speedKmh,
    String? sourceKey,
  }) {
    if (!_isValidDistance(distanceKm) || !speedKmh.isFinite || speedKmh <= 0) {
      return null;
    }
    final minutes = distanceKm / speedKmh * 60;
    return _estimateMinutes(
      met: met,
      weightKg: weightKg,
      durationMinutes: minutes,
      sourceKey: sourceKey,
    );
  }

  /// 回数 × [secondsPerRep] を分にしてから [estimate] と同じ MET 式。
  ExerciseCalorieEstimate? estimateByReps({
    required double met,
    required double weightKg,
    required int reps,
    String? sourceKey,
  }) {
    if (reps <= 0) {
      return null;
    }
    final minutes = reps * secondsPerRep / 60;
    final estimate = _estimateMinutes(
      met: met,
      weightKg: weightKg,
      durationMinutes: minutes,
      sourceKey: sourceKey,
    );
    if (estimate == null) {
      return null;
    }
    return ExerciseCalorieEstimate(
      met: estimate.met,
      weightKgSnapshot: estimate.weightKgSnapshot,
      grossKcal: estimate.grossKcal,
      netKcal: estimate.netKcal,
      calculationSource: estimate.calculationSource,
      calculationVersion: CalculationVersions.exerciseReps,
      sourceKey: estimate.sourceKey,
    );
  }

  /// 距離だけの記録で、必須の分カラムに入れる値。速度が無いときは 1。
  static int companionDurationMin({
    required double distanceKm,
    double? referenceSpeedKmh,
  }) {
    if (referenceSpeedKmh == null ||
        referenceSpeedKmh <= 0 ||
        distanceKm <= 0) {
      return 1;
    }
    final minutes = (distanceKm / referenceSpeedKmh * 60).round();
    if (minutes < 1) {
      return 1;
    }
    if (minutes >= 24 * 60) {
      return 24 * 60 - 1;
    }
    return minutes;
  }

  static int durationMinForReps(int reps) {
    if (reps <= 0) {
      return 1;
    }
    final minutes = (reps * secondsPerRep / 60).round();
    if (minutes < 1) {
      return 1;
    }
    if (minutes >= 24 * 60) {
      return 24 * 60 - 1;
    }
    return minutes;
  }

  ExerciseCalorieEstimate? _estimateMinutes({
    required double met,
    required double weightKg,
    required double durationMinutes,
    String? sourceKey,
  }) {
    if (!_isValidMet(met) ||
        !_isValidWeight(weightKg) ||
        !durationMinutes.isFinite ||
        durationMinutes <= 0 ||
        durationMinutes >= 24 * 60) {
      return null;
    }
    final gross = met * 3.5 * weightKg / 200 * durationMinutes;
    final activityMet = met - restingMet;
    final net = activityMet <= 0
        ? 0.0
        : activityMet * 3.5 * weightKg / 200 * durationMinutes;
    if (!gross.isFinite || !net.isFinite) {
      return null;
    }
    return ExerciseCalorieEstimate(
      met: met,
      weightKgSnapshot: weightKg,
      grossKcal: gross,
      netKcal: net,
      calculationSource: ExerciseCalculationSource.metEstimate,
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

  bool _isValidDistance(double distanceKm) =>
      distanceKm.isFinite && distanceKm > 0 && distanceKm < 500;
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
