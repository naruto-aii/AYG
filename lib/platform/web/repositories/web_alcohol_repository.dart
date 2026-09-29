import '../../../models/alcohol_entry.dart';
import '../../../repositories/contracts/alcohol_repository_base.dart';

/// Web向けインメモリ AlcoholRepository。
class AlcoholRepository implements AlcoholRepositoryBase {
  final List<AlcoholEntry> _entries = [];

  @override
  Future<void> save(AlcoholEntry entry) async {
    _entries.removeWhere((item) => item.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<void> saveAll(List<AlcoholEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<List<AlcoholEntry>> loadAll() async {
    final copy = List<AlcoholEntry>.from(_entries);
    copy.sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    return copy;
  }

  @override
  Future<void> delete(String entryId) async {
    final removed = _entries.where((entry) => entry.id == entryId).length;
    if (removed == 0) {
      throw StateError('Alcohol entry not found: $entryId');
    }
    _entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
  }
}
