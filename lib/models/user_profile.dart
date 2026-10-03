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
    this.displayName = '',
  });

  final DateTime birthDate;

  /// 消費カロリーの計算に使う。表示名とは別。
  final Gender gender;
  final double heightCm;
  final double weightKg;

  /// 利用者が登録したユーザー名。未入力は空文字。
  final String displayName;

  UserProfile copyWith({
    DateTime? birthDate,
    Gender? gender,
    double? heightCm,
    double? weightKg,
    String? displayName,
  }) {
    return UserProfile(
      birthDate: birthDate ?? this.birthDate,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      displayName: displayName ?? this.displayName,
    );
  }
}
