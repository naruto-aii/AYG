import '../models/health_profile_data.dart';

/// `health_sync_result` の result。
///
/// * success — アクティブエネルギーか体重が取れた
/// * success_zero — 読み取りは成功し、消費は 0 で体重サンプルは無い
/// * failed — アクティブエネルギーか体重の読み取りが失敗した
String healthSyncResult(HealthProfileData data) {
  if (data.readFailed(HealthReadType.activeEnergy) ||
      data.readFailed(HealthReadType.weight)) {
    return 'failed';
  }
  final kcal = data.activeEnergyBurnedKcal ?? 0;
  if (kcal == 0 && data.weightKg == null) {
    return 'success_zero';
  }
  return 'success';
}
