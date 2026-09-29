import '../../models/food_report.dart';

class FoodReportDisplayLabels {
  FoodReportDisplayLabels._();

  static String reason(FoodReportReasonCode code) {
    return switch (code) {
      FoodReportReasonCode.incorrectNutrition => '栄養情報が誤っている',
      FoodReportReasonCode.inappropriateName => '不適切な名前',
      FoodReportReasonCode.duplicate => '重複',
      FoodReportReasonCode.spam => 'スパム',
      FoodReportReasonCode.intellectualProperty => '知的財産',
      FoodReportReasonCode.other => 'その他',
    };
  }
}
