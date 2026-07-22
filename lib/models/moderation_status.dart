enum ModerationStatus { none, reported, underReview, hidden, suspended }

extension ModerationStatusX on ModerationStatus {
  String get storageValue => switch (this) {
    ModerationStatus.none => 'none',
    ModerationStatus.reported => 'reported',
    ModerationStatus.underReview => 'under_review',
    ModerationStatus.hidden => 'hidden',
    ModerationStatus.suspended => 'suspended',
  };

  static ModerationStatus? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'none' => ModerationStatus.none,
      'reported' => ModerationStatus.reported,
      'under_review' => ModerationStatus.underReview,
      'hidden' => ModerationStatus.hidden,
      'suspended' => ModerationStatus.suspended,
      _ => null,
    };
  }
}
