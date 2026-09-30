import '../models/calculation/weight_sample.dart';
import '../models/health_profile_data.dart';
import '../services/weight_for_target.dart';
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
          recordedAt: data.weightMeasuredAt ?? DateTime.now(),
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
    DateTime? manualMeasuredAt,
    required double? healthWeightKg,
    DateTime? healthMeasuredAt,
    required bool useHealthIntegration,
  }) async {
    final records = await repository.loadWeightRecords();
    final samples = <WeightSample>[
      for (final record in records)
        WeightSample(
          kg: record.weightKg,
          measuredAt: record.recordedAt,
          source: record.source,
        ),
    ];
    if (manualWeightKg != null && manualMeasuredAt != null) {
      samples.add(
        WeightSample(
          kg: manualWeightKg,
          measuredAt: manualMeasuredAt,
          source: WeightSource.manual,
        ),
      );
    }
    if (useHealthIntegration &&
        healthWeightKg != null &&
        healthMeasuredAt != null) {
      samples.add(
        WeightSample(
          kg: healthWeightKg,
          measuredAt: healthMeasuredAt,
          source: WeightSource.health,
        ),
      );
    }
    if (samples.isEmpty) {
      return manualWeightKg ?? (useHealthIntegration ? healthWeightKg : null);
    }
    return selectWeight(
      samples: samples,
      reference: DateTime.now(),
      fallbackKg: manualWeightKg,
    ).kg;
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
