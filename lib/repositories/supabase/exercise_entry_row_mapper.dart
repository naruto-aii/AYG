import '../../models/exercise_calculation_source.dart';
import '../../models/exercise_category.dart';
import '../../models/exercise_entry.dart';

class ExerciseEntryRowMapper {
  const ExerciseEntryRowMapper._();

  static ExerciseEntry fromRow(Map<String, dynamic> row) {
    return ExerciseEntry(
      id: row['entry_id'] as String,
      name: row['name'] as String,
      durationMin: row['duration_min'] as int,
      burnedKcal: (row['burned_kcal'] as num).toDouble(),
      loggedAt: DateTime.parse(row['logged_at'] as String),
      category: ExerciseCategoryX.tryParse(row['category_key'] as String?),
      activityId: row['activity_id'] as String?,
      intensity: row['intensity'] as String?,
      sets: (row['sets'] as num?)?.toInt(),
      reps: (row['reps'] as num?)?.toInt(),
      liftWeightKg: (row['lift_weight_kg'] as num?)?.toDouble(),
      metValue: (row['met_value'] as num?)?.toDouble(),
      grossKcal: (row['gross_kcal'] as num?)?.toDouble(),
      netKcal: (row['net_kcal'] as num?)?.toDouble(),
      weightKgSnapshot: (row['weight_kg_snapshot'] as num?)?.toDouble(),
      calculationSource: ExerciseCalculationSourceX.tryParse(
        row['calculation_source'] as String?,
      ),
      calculationVersion: row['calculation_version'] as String?,
      sourceKey: row['source_key'] as String?,
      notes: row['notes'] as String?,
    );
  }

  static Map<String, dynamic> toRow(
    ExerciseEntry entry, {
    required String userId,
  }) {
    return {
      'user_id': userId,
      'entry_id': entry.id,
      'name': entry.name,
      'duration_min': entry.durationMin,
      'burned_kcal': entry.burnedKcal,
      'logged_at': entry.loggedAt.toIso8601String(),
      'category_key': entry.category?.id,
      'activity_id': entry.activityId,
      'intensity': entry.intensity,
      'sets': entry.sets,
      'reps': entry.reps,
      'lift_weight_kg': entry.liftWeightKg,
      'met_value': entry.metValue,
      'gross_kcal': entry.grossKcal,
      'net_kcal': entry.netKcal,
      'weight_kg_snapshot': entry.weightKgSnapshot,
      'calculation_source': entry.calculationSource?.storageValue,
      'calculation_version': entry.calculationVersion,
      'source_key': entry.sourceKey,
      'notes': entry.notes,
    };
  }
}
