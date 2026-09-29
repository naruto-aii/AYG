import '../../models/saved_food.dart';

/// Isar 側の saved_foods 操作（SyncedSavedFoodRepository 用）。
abstract class SavedFoodLocalStore {
  Future<void> savePrivate(SavedFood food);

  Future<void> saveAllPrivate(List<SavedFood> foods);

  Future<void> updateOwn(SavedFood food);

  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  });

  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  });

  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  });

  Future<void> replaceAllOwnLocal(String ownerUserId, List<SavedFood> foods);

  Future<void> clearAllLocal();

  Future<List<SavedFood>> loadAllOwnIncludingDeleted(String ownerUserId);
}
