import '../models/health_profile_data.dart';
import 'local_write_guard.dart';

/// Health データ取得とローカル保存の抽象 Repository。
///
/// Purpose: "Nutrition calculation and fitness tracking."
abstract class HealthRepository {
  bool get isAvailable;

  Future<bool> requestPermissions();

  /// まだ許可が決まっていないときだけ、システムの許可シートを出す。
  ///
  /// [allowPrompt] が false のときは出さない。背面や拡張からは true にしない。
  /// シートを出したら true。出さなかったら false。
  Future<bool> ensureReadAuthorization({required bool allowPrompt}) async {
    return false;
  }

  Future<HealthProfileData> fetchProfileData();

  Future<void> saveWeightRecord(WeightRecord record);

  Future<void> saveWorkoutRecords(
    List<HealthWorkoutRecord> records, {
    LocalWriteGuard? mayWrite,
  });

  Future<List<WeightRecord>> loadWeightRecords();

  Future<List<HealthWorkoutRecord>> loadWorkoutRecords();
}
