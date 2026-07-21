import '../../../models/health_profile_data.dart';
import '../../../models/weight_entry.dart';
import '../../../repositories/contracts/weight_repository_base.dart';

class WebWeightRepository implements WeightRepositoryBase {
  final List<WeightEntry> _entries = [];

  @override
  Future<void> save(WeightEntry entry) async {
    _entries.add(entry);
  }

  @override
  Future<List<WeightEntry>> loadAll() async {
    final entries = List<WeightEntry>.from(_entries);
    entries.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return entries;
  }

  @override
  Future<double?> latestWeight({WeightSource? preferredSource}) async {
    final entries = await loadAll();
    if (entries.isEmpty) {
      return null;
    }

    if (preferredSource != null) {
      for (final entry in entries) {
        if (entry.source == preferredSource) {
          return entry.weightKg;
        }
      }
    }

    return entries.first.weightKg;
  }

  @override
  Future<List<WeightRecord>> loadWeightRecords() async {
    final entries = await loadAll();
    return entries.map(weightEntryToRecord).toList();
  }

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {
    await save(weightEntryFromRecord(record));
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
  }
}
