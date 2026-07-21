import '../models/health_profile_data.dart';
import 'health_repository.dart';

/// HealthRepository 共通処理。
class HealthRepositorySupport {
  const HealthRepositorySupport._();

  static Future<void> persistFetchedProfile(
    HealthRepository repository,
    HealthProfileData data,
  ) async {
    if (data.weightKg != null) {
      await repository.saveWeightRecord(
        WeightRecord(
          weightKg: data.weightKg!,
          recordedAt: DateTime.now(),
          source: WeightSource.health,
        ),
      );
    }

    if (data.workouts.isNotEmpty) {
      await repository.saveWorkoutRecords(data.workouts);
    }
  }

  static Future<double?> resolvePreferredWeight(
    HealthRepository repository, {
    required double? manualWeightKg,
    required double? healthWeightKg,
    required bool useHealthIntegration,
  }) async {
    if (useHealthIntegration) {
      final storedHealthWeight = await latestStoredWeight(
        repository,
        preferredSource: WeightSource.health,
      );
      return healthWeightKg ?? storedHealthWeight ?? manualWeightKg;
    }

    final storedManualWeight = await latestStoredWeight(
      repository,
      preferredSource: WeightSource.manual,
    );
    return storedManualWeight ?? manualWeightKg;
  }

  static Future<double?> latestStoredWeight(
    HealthRepository repository, {
    WeightSource? preferredSource,
  }) async {
    final records = [...await repository.loadWeightRecords()];
    if (records.isEmpty) {
      return null;
    }

    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    if (preferredSource != null) {
      for (final record in records) {
        if (record.source == preferredSource) {
          return record.weightKg;
        }
      }
    }

    return records.first.weightKg;
  }
}
