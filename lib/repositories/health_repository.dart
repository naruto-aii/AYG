import '../models/health_profile_data.dart';

/// Health データ取得とローカル保存の抽象 Repository。
///
/// Purpose: "Nutrition calculation and fitness tracking."
abstract class HealthRepository {
  bool get isAvailable;

  /// Last request/fetch failure, in Japanese when set by the platform impl.
  String? get lastFailureMessage;

  Future<bool> requestPermissions();

  Future<HealthProfileData> fetchProfileData();

  Future<void> saveWeightRecord(WeightRecord record);

  Future<void> saveWorkoutRecords(List<HealthWorkoutRecord> records);

  Future<List<WeightRecord>> loadWeightRecords();

  Future<List<HealthWorkoutRecord>> loadWorkoutRecords();
}
