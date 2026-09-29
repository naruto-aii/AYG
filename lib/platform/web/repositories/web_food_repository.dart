import '../../../models/food_entry.dart';
import '../../../repositories/contracts/food_repository_base.dart';

/// Web向けインメモリ FoodRepository。
class FoodRepository implements FoodRepositoryBase {
  final List<FoodEntry> _entries = [];

  @override
  Future<void> save(FoodEntry entry) async {
    _entries.removeWhere((item) => item.id == entry.id);
    _entries.add(entry);
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<List<FoodEntry>> loadAll() async {
    final copy = List<FoodEntry>.from(_entries);
    copy.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return copy;
  }

  @override
  Future<void> delete(String entryId) async {
    _entries.removeWhere((entry) => entry.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
  }
}
