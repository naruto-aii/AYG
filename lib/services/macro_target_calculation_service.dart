import '../models/calculation/calculation_versions.dart';
import '../models/calculation/macro_target_breakdown.dart';
import '../models/exercise_category.dart';
import '../models/goal.dart';

/// ISSN / AMDR を参考にした PFC 目標（文献範囲とプロダクト既定を区別）。
class MacroTargetCalculationService {
  const MacroTargetCalculationService();

  static const proteinKcalPerGram = 4.0;
  static const fatKcalPerGram = 9.0;
  static const carbKcalPerGram = 4.0;

  /// AMDR 参考範囲（% of total energy）。
  static const amdrProteinPercent = (10.0, 35.0);
  static const amdrFatPercent = (20.0, 35.0);
  static const amdrCarbPercent = (45.0, 65.0);

  /// 脂質エネルギー比率のプロダクト既定値。
  static const defaultFatEnergyRatio = 0.28;

  MacroTargetBreakdown calculate({
    required GoalType goalType,
    required double goalFoodTargetKcal,
    required double referenceWeightKg,
    bool hasStrengthTrainingHabit = false,
  }) {
    final productDefaults = <String>[];
    final proteinGPerKg = _proteinGPerKg(
      goalType: goalType,
      hasStrengthTraining: hasStrengthTrainingHabit,
    );
    final proteinReason = _proteinReason(
      goalType: goalType,
      hasStrengthTraining: hasStrengthTrainingHabit,
      proteinGPerKg: proteinGPerKg,
    );
    productDefaults.add(
      'たんぱく質 ${proteinGPerKg.toStringAsFixed(2)} g/kg（アプリ既定）',
    );

    final fatRatio = defaultFatEnergyRatio;
    productDefaults.add(
      '脂質エネルギー比率 ${(fatRatio * 100).toStringAsFixed(0)}%（アプリ既定・AMDR 20–35% 内）',
    );

    final proteinG = proteinGPerKg * referenceWeightKg;
    final fatKcal = goalFoodTargetKcal * fatRatio;
    final fatG = fatKcal / fatKcalPerGram;
    final proteinKcal = proteinG * proteinKcalPerGram;
    final carbKcal = goalFoodTargetKcal - proteinKcal - fatKcal;
    final carbG = carbKcal > 0 ? carbKcal / carbKcalPerGram : 0.0;

    final actualProteinPct = goalFoodTargetKcal > 0
        ? (proteinKcal / goalFoodTargetKcal) * 100
        : null;
    final actualFatPct = goalFoodTargetKcal > 0
        ? (fatKcal / goalFoodTargetKcal) * 100
        : null;
    final actualCarbPct = goalFoodTargetKcal > 0
        ? (carbKcal / goalFoodTargetKcal) * 100
        : null;

    final warnings = <String>[];
    _checkAmdr(
      warnings: warnings,
      label: 'たんぱく質',
      actual: actualProteinPct,
      range: amdrProteinPercent,
    );
    _checkAmdr(
      warnings: warnings,
      label: '脂質',
      actual: actualFatPct,
      range: amdrFatPercent,
    );
    _checkAmdr(
      warnings: warnings,
      label: '炭水化物',
      actual: actualCarbPct,
      range: amdrCarbPercent,
    );

    return MacroTargetBreakdown(
      version: CalculationVersions.macro,
      referenceWeightKg: referenceWeightKg,
      goalFoodTargetKcal: goalFoodTargetKcal,
      proteinGPerKg: proteinGPerKg,
      proteinReason: proteinReason,
      fatEnergyRatio: fatRatio,
      fatReason:
          '総エネルギーの ${(fatRatio * 100).toStringAsFixed(0)}% を脂質に配分（残余は炭水化物）',
      proteinG: proteinG,
      fatG: fatG,
      carbG: carbG,
      proteinKcal: proteinKcal,
      fatKcal: fatKcal,
      carbKcal: carbKcal,
      amdrProteinPercentRange: amdrProteinPercent,
      amdrFatPercentRange: amdrFatPercent,
      amdrCarbPercentRange: amdrCarbPercent,
      actualProteinPercent: actualProteinPct,
      actualFatPercent: actualFatPct,
      actualCarbPercent: actualCarbPct,
      amdrWarnings: warnings,
      productDefaultsUsed: productDefaults,
      calculatedAt: DateTime.now(),
    );
  }

  double _proteinGPerKg({
    required GoalType goalType,
    required bool hasStrengthTraining,
  }) {
    // ISSN 1.4–2.0 g/kg/day を参考にしたプロダクト既定（一般向け自動適用）。
    if (hasStrengthTraining) {
      return switch (goalType) {
        GoalType.lose => 1.9,
        GoalType.maintain => 1.7,
        GoalType.gain => 2.0,
      };
    }
    return switch (goalType) {
      GoalType.lose => 1.6,
      GoalType.maintain => 1.4,
      GoalType.gain => 1.6,
    };
  }

  String _proteinReason({
    required GoalType goalType,
    required bool hasStrengthTraining,
    required double proteinGPerKg,
  }) {
    final base = hasStrengthTraining
        ? '筋力トレーニング習慣あり（ISSN 1.4–2.0 g/kg/day を参考）'
        : '一般的な成人（ISSN 1.4–2.0 g/kg/day を参考）';
    final goal = switch (goalType) {
      GoalType.lose => '減量目標',
      GoalType.maintain => '維持目標',
      GoalType.gain => '増量目標',
    };
    return '$base・$goal → ${proteinGPerKg.toStringAsFixed(2)} g/kg（アプリ既定）';
  }

  void _checkAmdr({
    required List<String> warnings,
    required String label,
    required double? actual,
    required (double, double) range,
  }) {
    if (actual == null) {
      return;
    }
    if (actual < range.$1 || actual > range.$2) {
      warnings.add(
        '$label が AMDR 参考範囲（${range.$1.toStringAsFixed(0)}–${range.$2.toStringAsFixed(0)}%）外: '
        '${actual.toStringAsFixed(1)}%',
      );
    }
  }

  bool inferStrengthTrainingHabit({
    required List<ExerciseCategory?> recentCategories,
  }) {
    return recentCategories.any((c) => c == ExerciseCategory.strength);
  }
}
