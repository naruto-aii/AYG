import '../../../models/health_profile_data.dart';
import '../../../models/weight_entry.dart';
import '../../../repositories/contracts/weight_repository_base.dart';
import '../../../repositories/health_repository_support.dart';

/// Web向けインメモリ WeightRepository。
class WeightRepository implements WeightRepositoryBase {
  final List<WeightEntry> _entries = [];

  @override
  Future<void> save(WeightEntry entry) async {
    _entries.removeWhere((item) => item.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<void> delete(String entryId) async {
    _entries.removeWhere((item) => item.id == entryId);
  }

  @override
  Future<List<WeightEntry>> loadAll() async {
    final copy = List<WeightEntry>.from(_entries);
    copy.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return copy;
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
