enum Gender {
  male('男性'),
  female('女性'),
  other('その他');

  const Gender(this.label);
  final String label;
}

class UserProfile {
  UserProfile({
    required this.birthDate,
    required this.gender,
    required this.heightCm,
    required this.weightKg,
  });

  final DateTime birthDate;
  final Gender gender;
  final double heightCm;
  final double weightKg;

  UserProfile copyWith({
    DateTime? birthDate,
    Gender? gender,
    double? heightCm,
    double? weightKg,
  }) {
    return UserProfile(
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
    );
  }
}
