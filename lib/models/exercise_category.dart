enum ExerciseCategory { aerobic, strength, sport, flexibility, other }

extension ExerciseCategoryX on ExerciseCategory {
  String get id => name;

  String get labelJa => switch (this) {
    ExerciseCategory.aerobic => '有酸素運動',
    ExerciseCategory.strength => '筋力トレーニング',
    ExerciseCategory.sport => 'スポーツ',
    ExerciseCategory.flexibility => '柔軟・コンディショニング',
    ExerciseCategory.other => 'その他',
  };

  static ExerciseCategory? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'aerobic' => ExerciseCategory.aerobic,
      'strength' => ExerciseCategory.strength,
      'sport' => ExerciseCategory.sport,
      'flexibility' => ExerciseCategory.flexibility,
      'other' => ExerciseCategory.other,
      _ => null,
    };
  }
}
