import '../../models/food_entry.dart';

abstract class FoodRepositoryBase {
  Future<void> save(FoodEntry entry);

  Future<void> saveAll(List<FoodEntry> entries);

  Future<List<FoodEntry>> loadAll();

  Future<void> delete(String entryId);

  Future<void> clearAll();
}
