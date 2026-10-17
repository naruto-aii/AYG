import '../models/user_profile.dart';
import '../models/weight_entry.dart';
import '../utils/record_clock.dart';

/// 運動実施日時以前で最も新しい体重を参照する。
class ExerciseWeightResolver {
  const ExerciseWeightResolver();

  WeightReference? resolve({
    required DateTime exerciseLoggedAt,
    required List<WeightEntry> weightEntries,
    UserProfile? profile,
  }) {
    final beforeOrAt =
        weightEntries
            .where(
              (entry) =>
                  compareRecordInstants(entry.recordedAt, exerciseLoggedAt) <=
                  0,
            )
            .toList()
          ..sort((a, b) => compareRecordInstants(b.recordedAt, a.recordedAt));

    if (beforeOrAt.isNotEmpty) {
      final latest = beforeOrAt.first;
      return WeightReference(
        weightKg: latest.weightKg,
        source: WeightReferenceSource.weightEntry,
        recordedAt: latest.recordedAt,
      );
    }

    if (profile != null && profile.weightKg > 0) {
      return WeightReference(
        weightKg: profile.weightKg,
        source: WeightReferenceSource.profile,
      );
    }

    return null;
  }
}

enum WeightReferenceSource { weightEntry, profile }

class WeightReference {
  const WeightReference({
    required this.weightKg,
    required this.source,
    this.recordedAt,
  });

  final double weightKg;
  final WeightReferenceSource source;
  final DateTime? recordedAt;
}
