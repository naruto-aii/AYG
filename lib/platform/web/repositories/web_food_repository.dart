import '../../../models/food_entry.dart';
import '../../../repositories/contracts/food_repository_base.dart';

class WebFoodRepository implements FoodRepositoryBase {
  final List<FoodEntry> _entries = [];

  @override
  Future<void> save(FoodEntry entry) async {
    final index = _entries.indexWhere((item) => item.id == entry.id);
    if (index == -1) {
      _entries.add(entry);
      return;
    }
    _entries[index] = entry;
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    for (final entry in entries) {
      await save(entry);
    }
  }

  @override
  Future<List<FoodEntry>> loadAll() async {
    final entries = List<FoodEntry>.from(_entries);
    entries.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return entries;
  }

  @override
  Future<void> delete(String entryId) async {
    _entries.removeWhere((item) => item.id == entryId);
  }

  @override
  Future<void> clearAll() async {
    _entries.clear();
  }
}
