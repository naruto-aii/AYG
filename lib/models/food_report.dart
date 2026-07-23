enum FoodReportReasonCode {
  incorrectNutrition,
  inappropriateName,
  duplicate,
  spam,
  intellectualProperty,
  other,
}

extension FoodReportReasonCodeX on FoodReportReasonCode {
  String get storageValue => switch (this) {
    FoodReportReasonCode.incorrectNutrition => 'incorrect_nutrition',
    FoodReportReasonCode.inappropriateName => 'inappropriate_name',
    FoodReportReasonCode.duplicate => 'duplicate',
    FoodReportReasonCode.spam => 'spam',
    FoodReportReasonCode.intellectualProperty => 'intellectual_property',
    FoodReportReasonCode.other => 'other',
  };

  static FoodReportReasonCode? tryParse(String? raw) {
    if (raw == null) {
      return null;
    }
    return switch (raw) {
      'incorrect_nutrition' => FoodReportReasonCode.incorrectNutrition,
      'inappropriate_name' => FoodReportReasonCode.inappropriateName,
      'duplicate' => FoodReportReasonCode.duplicate,
      'spam' => FoodReportReasonCode.spam,
      'intellectual_property' => FoodReportReasonCode.intellectualProperty,
      'other' => FoodReportReasonCode.other,
      _ => null,
    };
  }
}

class FoodReport {
  const FoodReport({
    required this.reportId,
    required this.reporterUserId,
    required this.targetFoodOwnerUserId,
    required this.targetFoodId,
    required this.reasonCode,
    this.detailText,
    required this.createdAt,
  });

  final String reportId;
  final String reporterUserId;
  final String targetFoodOwnerUserId;
  final String targetFoodId;
  final FoodReportReasonCode reasonCode;
  final String? detailText;
  final DateTime createdAt;
}
