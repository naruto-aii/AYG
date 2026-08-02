enum ExerciseCalculationSource { metEstimate, manualOverride, template }

extension ExerciseCalculationSourceX on ExerciseCalculationSource {
  String get storageValue => switch (this) {
    ExerciseCalculationSource.metEstimate => 'met_estimate',
    ExerciseCalculationSource.manualOverride => 'manual_override',
    ExerciseCalculationSource.template => 'template',
  };

  static ExerciseCalculationSource? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'met_estimate' => ExerciseCalculationSource.metEstimate,
      'manual_override' => ExerciseCalculationSource.manualOverride,
      'template' => ExerciseCalculationSource.template,
      _ => null,
    };
  }
}
