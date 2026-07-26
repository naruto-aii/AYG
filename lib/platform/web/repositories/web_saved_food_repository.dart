import '../../../models/food_status.dart';
import '../../../models/saved_food.dart';
import '../../../repositories/contracts/saved_food_repository_base.dart';
import '../../../utils/food_name_normalizer.dart';

/// Web Preview 向け in-memory 保存済み食品 Repository。
class WebSavedFoodRepository extends SavedFoodRepositoryBase {
  final Map<String, SavedFood> _foods = {};

  String _key(String ownerUserId, String foodId) => '$ownerUserId:$foodId';

  @override
  Future<void> savePrivate(SavedFood food) async {
    _foods[_key(food.ownerUserId, food.foodId)] = food;
  }

  @override
  Future<void> updateOwn(SavedFood food) => savePrivate(food);

  @override
  Future<SavedFood> publish({
    required String ownerUserId,
    required String foodId,
  }) {
    throw UnsupportedError('publish is not available on web preview');
  }

  @override
  Future<SavedFood> unpublish({
    required String ownerUserId,
    required String foodId,
  }) {
    throw UnsupportedError('unpublish is not available on web preview');
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
  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  }) async {
    return _foods[_key(ownerUserId, foodId)];
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
  Future<List<SavedFood>> searchPublic({
    required String query,
    int limit = 50,
  }) {
    throw UnsupportedError('searchPublic is not available on web preview');
  }

  @override
  Future<SavedFood?> getPublicById({
    required String ownerUserId,
    required String foodId,
  }) {
    throw UnsupportedError('getPublicById is not available on web preview');
  }

  @override
  Future<SavedFood> copyPublicToPrivate({
    required SavedFood source,
    required String newFoodId,
    required String ownerUserId,
    required DateTime now,
  }) {
    throw UnsupportedError(
      'copyPublicToPrivate is not available on web preview',
    );
  }

  @override
  Future<void> replaceAllOwnLocal(
    String ownerUserId,
    List<SavedFood> foods,
  ) async {
    _foods.removeWhere((key, _) => key.startsWith('$ownerUserId:'));
    for (final food in foods) {
      await savePrivate(food);
    }
  }

  @override
  Future<List<SavedFood>> pullAllOwnRemote(String ownerUserId) {
    throw UnsupportedError('pullAllOwnRemote is not available on web preview');
  }

  @override
  Future<void> pushAllOwnRemote(String ownerUserId, List<SavedFood> foods) {
    throw UnsupportedError('pushAllOwnRemote is not available on web preview');
  }

  @override
  Future<void> clearAllLocal() async {
    _foods.clear();
  }
}
