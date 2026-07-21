import 'health_profile_data.dart';

/// 体重記録（ローカルDB保存用）。
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.weightKg,
    required this.recordedAt,
    required this.source,
  });

  final String id;
  final double weightKg;
  final DateTime recordedAt;
  final WeightSource source;

  WeightEntry copyWith({
    String? id,
    double? weightKg,
    DateTime? recordedAt,
    WeightSource? source,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      weightKg: weightKg ?? this.weightKg,
      recordedAt: recordedAt ?? this.recordedAt,
      source: source ?? this.source,
    );
  }
}

WeightEntry weightEntryFromRecord(WeightRecord record) {
  return WeightEntry(
    id: '${record.recordedAt.millisecondsSinceEpoch}_${record.source.storageValue}',
    weightKg: record.weightKg,
    recordedAt: record.recordedAt,
    source: record.source,
  );
}

WeightRecord weightEntryToRecord(WeightEntry entry) {
  return WeightRecord(
    weightKg: entry.weightKg,
    recordedAt: entry.recordedAt,
    source: entry.source,
  );
}
