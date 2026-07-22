import '../../models/saved_food.dart';

abstract class SavedFoodRepositoryBase {
  Future<void> save(SavedFood food);

  Future<void> saveAll(List<SavedFood> foods);

  Future<SavedFood?> getById({
    required String ownerUserId,
    required String foodId,
  });

  Future<List<SavedFood>> getAllOwn(String ownerUserId);

  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  });

  Future<void> update(SavedFood food);

  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  });

  Future<void> clearAll();
}
