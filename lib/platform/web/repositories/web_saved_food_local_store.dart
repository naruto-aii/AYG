import '../../../models/food_status.dart';
import '../../../models/saved_food.dart';
import '../../../repositories/contracts/saved_food_local_store.dart';
import '../../../utils/food_name_normalizer.dart';

/// Web Preview 向け in-memory SavedFood local store。
class WebSavedFoodLocalStore implements SavedFoodLocalStore {
  final Map<String, SavedFood> _foods = {};

  String _key(String ownerUserId, String foodId) => '$ownerUserId:$foodId';

  @override
  Future<void> clearAllLocal() async {
    _foods.clear();
  }

  @override
  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  }) async => _foods[_key(ownerUserId, foodId)];

  @override
  Future<List<SavedFood>> loadAllOwnIncludingDeleted(
    String ownerUserId,
  ) async =>
      _foods.values.where((food) => food.ownerUserId == ownerUserId).toList();

  @override
  Future<void> replaceAllOwnLocal(
    String ownerUserId,
    List<SavedFood> foods,
  ) async {
    _foods.removeWhere((key, _) => key.startsWith('$ownerUserId:'));
    for (final food in foods) {
      _foods[_key(food.ownerUserId, food.foodId)] = food;
    }
  }

  @override
  Future<void> saveAllPrivate(List<SavedFood> foods) async {
    for (final food in foods) {
      await savePrivate(food);
    }
  }

  @override
  Future<void> savePrivate(SavedFood food) async {
    _foods[_key(food.ownerUserId, food.foodId)] = food;
  }

  @override
  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  }) async {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    return _foods.values
        .where(
          (food) =>
              food.ownerUserId == ownerUserId &&
              food.status == FoodStatus.active &&
              food.deletedAt == null &&
              (normalizedQuery.isEmpty ||
                  food.normalizedName.contains(normalizedQuery)),
        )
        .toList();
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  }) async {
    final food = await getOwn(ownerUserId: ownerUserId, foodId: foodId);
    if (food == null) {
      return;
    }
    await savePrivate(
      food.copyWith(
        status: FoodStatus.deleted,
        deletedAt: deletedAt,
        updatedAt: deletedAt,
      ),
    );
  }

  @override
  Future<void> updateOwn(SavedFood food) => savePrivate(food);
}
