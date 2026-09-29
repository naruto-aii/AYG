import 'calculation_versions.dart';

class MacroTargetBreakdown {
  const MacroTargetBreakdown({
    required this.version,
    required this.referenceWeightKg,
    required this.goalFoodTargetKcal,
    required this.proteinGPerKg,
    required this.proteinReason,
    required this.fatEnergyRatio,
    required this.fatReason,
    required this.proteinG,
    required this.fatG,
    required this.carbG,
    required this.proteinKcal,
    required this.fatKcal,
    required this.carbKcal,
    required this.amdrProteinPercentRange,
    required this.amdrFatPercentRange,
    required this.amdrCarbPercentRange,
    required this.actualProteinPercent,
    required this.actualFatPercent,
    required this.actualCarbPercent,
    required this.amdrWarnings,
    required this.productDefaultsUsed,
    required this.calculatedAt,
  });

  final String version;
  final double referenceWeightKg;
  final double goalFoodTargetKcal;
  final double proteinGPerKg;
  final String proteinReason;
  final double fatEnergyRatio;
  final String fatReason;
  final double proteinG;
  final double fatG;
  final double carbG;
  final double proteinKcal;
  final double fatKcal;
  final double carbKcal;
  final (double min, double max) amdrProteinPercentRange;
  final (double min, double max) amdrFatPercentRange;
  final (double min, double max) amdrCarbPercentRange;
  final double? actualProteinPercent;
  final double? actualFatPercent;
  final double? actualCarbPercent;
  final List<String> amdrWarnings;
  final List<String> productDefaultsUsed;
  final DateTime calculatedAt;

  double get macroKcalTotal => proteinKcal + fatKcal + carbKcal;
}
