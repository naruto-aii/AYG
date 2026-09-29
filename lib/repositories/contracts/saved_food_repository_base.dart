import '../../models/food_unit_type.dart';
import '../../models/saved_food.dart';

/// 保存済み食品 Repository（Local First + Supabase）。
abstract class SavedFoodRepositoryBase {
  Future<void> savePrivate(SavedFood food);

  Future<void> updateOwn(SavedFood food);

  Future<SavedFood> publish({
    required String ownerUserId,
    required String foodId,
  });

  Future<SavedFood> unpublish({
    required String ownerUserId,
    required String foodId,
  });

  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  });

  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  });

  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  });

  Future<List<SavedFood>> searchPublic({required String query, int limit = 50});

  Future<SavedFood?> getPublicById({
    required String ownerUserId,
    required String foodId,
  });

  Future<SavedFood?> findExactPublicDuplicate({
    required String normalizedName,
    required double baseAmount,
    required FoodUnitType unitType,
    String? excludeOwnerUserId,
    String? excludeFoodId,
  });

  Future<List<SavedFood>> findSimilarPublicFoods({
    required SavedFood food,
    int limit = 20,
  });

  Future<SavedFood> copyPublicToPrivate({
    required SavedFood source,
    required String newFoodId,
    required String ownerUserId,
    required DateTime now,
  });

  /// DataSync: replace all own rows locally after pull.
  Future<void> replaceAllOwnLocal(String ownerUserId, List<SavedFood> foods);

  /// DataSync: fetch all own rows from remote (includes soft-deleted).
  Future<List<SavedFood>> pullAllOwnRemote(String ownerUserId);

  /// DataSync: push all own rows to remote.
  Future<void> pushAllOwnRemote(String ownerUserId, List<SavedFood> foods);

  Future<void> clearAllLocal();

  @Deprecated('Use savePrivate')
  Future<void> save(SavedFood food) => savePrivate(food);

  @Deprecated('Use updateOwn')
  Future<void> update(SavedFood food) => updateOwn(food);

  @Deprecated('Use getOwn')
  Future<SavedFood?> getById({
    required String ownerUserId,
    required String foodId,
  }) => getOwn(ownerUserId: ownerUserId, foodId: foodId);

  @Deprecated('Use searchOwn')
  Future<List<SavedFood>> getAllOwn(String ownerUserId) =>
      searchOwn(ownerUserId: ownerUserId, query: '');

  @Deprecated('Use clearAllLocal')
  Future<void> clearAll() => clearAllLocal();
}
