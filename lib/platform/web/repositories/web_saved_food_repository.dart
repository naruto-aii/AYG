import '../../../models/food_status.dart';
import '../../../models/food_unit_type.dart';
import '../../../models/saved_food.dart';
import '../../../repositories/contracts/saved_food_local_store.dart';
import '../../../repositories/contracts/saved_food_repository_base.dart';
import '../../../utils/food_name_normalizer.dart';

/// Web向けインメモリ saved_foods ローカルストア。
class IsarSavedFoodRepository extends SavedFoodRepositoryBase
    implements SavedFoodLocalStore {
  final List<SavedFood> _foods = [];

  @override
  Future<void> savePrivate(SavedFood food) async {
    _foods.removeWhere(
      (item) =>
          item.foodId == food.foodId && item.ownerUserId == food.ownerUserId,
    );
    _foods.add(food);
  }

  @override
  Future<void> saveAllPrivate(List<SavedFood> foods) async {
    for (final food in foods) {
      await savePrivate(food);
    }
  }

  @override
  Future<void> updateOwn(SavedFood food) async {
    await savePrivate(food);
  }

  @override
  Future<SavedFood> publish({
    required String ownerUserId,
    required String foodId,
  }) {
    throw UnsupportedError('Use SyncedSavedFoodRepository.publish');
  }

  @override
  Future<SavedFood> unpublish({
    required String ownerUserId,
    required String foodId,
  }) {
    throw UnsupportedError('Use SyncedSavedFoodRepository.unpublish');
  }

  @override
  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  }) async {
    for (final food in _foods) {
      if (food.foodId == foodId && food.ownerUserId == ownerUserId) {
        return food;
      }
    }
    return null;
  }

  @override
  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  }) async {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    final foods =
        _foods
            .where(
              (food) =>
                  food.ownerUserId == ownerUserId &&
                  food.status == FoodStatus.active &&
                  (normalizedQuery.isEmpty ||
                      food.normalizedName.contains(normalizedQuery)),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return foods;
  }

  @override
  Future<List<SavedFood>> searchPublic({
    required String query,
    int limit = 50,
  }) {
    throw UnsupportedError('Use SyncedSavedFoodRepository.searchPublic');
  }

  @override
  Future<SavedFood?> getPublicById({
    required String ownerUserId,
    required String foodId,
  }) {
    throw UnsupportedError('Use SyncedSavedFoodRepository.getPublicById');
  }

  @override
  Future<SavedFood?> findExactPublicDuplicate({
    required String normalizedName,
    required double baseAmount,
    required FoodUnitType unitType,
    String? excludeOwnerUserId,
    String? excludeFoodId,
  }) {
    throw UnsupportedError(
      'Use SyncedSavedFoodRepository.findExactPublicDuplicate',
    );
  }

  @override
  Future<List<SavedFood>> findSimilarPublicFoods({
    required SavedFood food,
    int limit = 20,
  }) {
    throw UnsupportedError(
      'Use SyncedSavedFoodRepository.findSimilarPublicFoods',
    );
  }

  @override
  Future<SavedFood> copyPublicToPrivate({
    required SavedFood source,
    required String newFoodId,
    required String ownerUserId,
    required DateTime now,
  }) {
    throw UnsupportedError('Use SyncedSavedFoodRepository.copyPublicToPrivate');
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  }) async {
    for (var i = 0; i < _foods.length; i++) {
      final food = _foods[i];
      if (food.foodId == foodId && food.ownerUserId == ownerUserId) {
        _foods[i] = food.copyWith(
          status: FoodStatus.deleted,
          deletedAt: deletedAt,
          updatedAt: deletedAt,
        );
        return;
      }
    }
  }

  @override
  Future<void> replaceAllOwnLocal(
    String ownerUserId,
    List<SavedFood> foods,
  ) async {
    _foods.removeWhere((food) => food.ownerUserId == ownerUserId);
    await saveAllPrivate(foods);
  }

  @override
  Future<List<SavedFood>> pullAllOwnRemote(String ownerUserId) {
    throw UnsupportedError('Use SyncedSavedFoodRepository');
  }

  @override
  Future<void> pushAllOwnRemote(String ownerUserId, List<SavedFood> foods) {
    throw UnsupportedError('Use SyncedSavedFoodRepository');
  }

  @override
  Future<void> clearAllLocal() async {
    _foods.clear();
  }

  @override
  Future<List<SavedFood>> loadAllOwnIncludingDeleted(String ownerUserId) async {
    return _foods.where((food) => food.ownerUserId == ownerUserId).toList();
  }
}

typedef SavedFoodRepository = IsarSavedFoodRepository;
