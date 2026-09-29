import '../../models/food_report.dart';

abstract class FoodReportRepositoryBase {
  Future<FoodReport> submitReport({
    required String reportId,
    required String reporterUserId,
    required String targetFoodOwnerUserId,
    required String targetFoodId,
    required FoodReportReasonCode reasonCode,
    String? detailText,
  });

  Future<List<FoodReport>> getMyReports(String reporterUserId);
}
