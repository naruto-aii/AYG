import '../models/health_profile_data.dart';

/// `health_sync_result` の result。
///
/// * success — アクティブエネルギーか体重が取れた
/// * success_zero — 読み取りは成功し、消費は 0 で体重サンプルは無い
/// * no_sample — この端末ではまだ実データが無く、空の読み取り（未許可の可能性）
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

/// この端末で実データを受け取る前の空読みは [healthSyncResult] の success_zero にしない。
String healthSyncResultForInstall(
  HealthProfileData data, {
  required bool installHasSeenSample,
}) {
  final raw = healthSyncResult(data);
  if (raw == 'failed') {
    return raw;
  }
  if (!installHasSeenSample && !data.receivedHealthSample) {
    return 'no_sample';
  }
  return raw;
}
