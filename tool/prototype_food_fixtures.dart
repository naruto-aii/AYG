import 'package:ayg/models/food_rating.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/food_rating_repository_base.dart';
import 'package:ayg/repositories/contracts/saved_food_local_store.dart';
import 'package:ayg/repositories/contracts/saved_food_remote_store.dart';
import 'package:ayg/repositories/synced_saved_food_repository.dart';
import 'package:ayg/state/app_controller.dart';

import '../test/mocks/mock_authentication_repository.dart';
import '../test/mocks/mock_health_repository.dart';

const prototypeUserId = 'prototype-user';

List<SavedFood> prototypeOwnFoods(DateTime now) {
  return [
    SavedFood(
      foodId: 'own-1',
      ownerUserId: prototypeUserId,
      name: 'サラダチキン',
      normalizedName: 'サラダチキン',
      baseAmount: 100,
      unitType: FoodUnitType.g,
      kcalPerBase: 428,
      proteinPerBase: 50,
      fatPerBase: 8,
      carbPerBase: 2,
      visibility: FoodVisibility.private,
      sourceType: FoodSourceType.manual,
      status: FoodStatus.active,
      createdAt: now,
      updatedAt: now,
    ),
    SavedFood(
      foodId: 'own-2',
      ownerUserId: prototypeUserId,
      name: '玄米おにぎり',
      normalizedName: '玄米おにぎり',
      baseAmount: 1,
      unitType: FoodUnitType.piece,
      kcalPerBase: 586,
      proteinPerBase: 12,
      fatPerBase: 4,
      carbPerBase: 120,
      visibility: FoodVisibility.public,
      sourceType: FoodSourceType.manual,
      status: FoodStatus.active,
      version: 2,
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 5)),
    ),
    SavedFood(
      foodId: 'own-3',
      ownerUserId: prototypeUserId,
      name: 'オートミール',
      normalizedName: 'オートミール',
      baseAmount: 40,
      unitType: FoodUnitType.g,
      kcalPerBase: 150,
      proteinPerBase: 5,
      fatPerBase: 3,
      carbPerBase: 27,
      brand: '日清',
      visibility: FoodVisibility.private,
      sourceType: FoodSourceType.manual,
      status: FoodStatus.active,
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
  ];
}

/// Screenshot seed query shared by prototype public-food fixtures.
const prototypePublicSearchSeedQuery = 'あ';

List<SavedFood> prototypePublicFoods(DateTime now) {
  return [
    SavedFood(
      foodId: 'pub-1',
      ownerUserId: 'creator-a',
      name: 'サラダチキン（公開）',
      normalizedName: 'あサラダチキン',
      baseAmount: 100,
      unitType: FoodUnitType.g,
      kcalPerBase: 428,
      proteinPerBase: 50,
      fatPerBase: 8,
      carbPerBase: 2,
      brand: 'アサヒフード',
      visibility: FoodVisibility.public,
      sourceType: FoodSourceType.manual,
      status: FoodStatus.active,
      version: 2,
      createdAt: now,
      updatedAt: now,
    ),
    SavedFood(
      foodId: 'pub-2',
      ownerUserId: 'creator-b',
      name: '玄米おにぎり',
      normalizedName: 'あ玄米おにぎり',
      baseAmount: 1,
      unitType: FoodUnitType.piece,
      kcalPerBase: 586,
      proteinPerBase: 12,
      fatPerBase: 4,
      carbPerBase: 120,
      visibility: FoodVisibility.public,
      sourceType: FoodSourceType.manual,
      status: FoodStatus.active,
      version: 1,
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
    SavedFood(
      foodId: 'pub-3',
      ownerUserId: 'creator-c',
      name: 'オートミール',
      normalizedName: 'あオートミール',
      baseAmount: 40,
      unitType: FoodUnitType.g,
      kcalPerBase: 150,
      proteinPerBase: 5,
      fatPerBase: 3,
      carbPerBase: 27,
      brand: 'クオカ',
      visibility: FoodVisibility.public,
      sourceType: FoodSourceType.manual,
      status: FoodStatus.active,
      version: 3,
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
  ];
}

class _PrototypeLocalStore implements SavedFoodLocalStore {
  _PrototypeLocalStore(this._ownFoods);

  final List<SavedFood> _ownFoods;

  @override
  Future<void> clearAllLocal() async {}

  @override
  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  }) async => null;

  @override
  Future<List<SavedFood>> loadAllOwnIncludingDeleted(
    String ownerUserId,
  ) async => _ownFoods;

  @override
  Future<void> replaceAllOwnLocal(
    String ownerUserId,
    List<SavedFood> foods,
  ) async {}

  @override
  Future<void> saveAllPrivate(List<SavedFood> foods) async {}

  @override
  Future<void> savePrivate(SavedFood food) async {}

  @override
  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  }) async {
    if (query.trim().isEmpty) {
      return _ownFoods;
    }
    return _ownFoods
        .where((food) => food.name.contains(query.trim()))
        .toList(growable: false);
  }

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<void> updateOwn(SavedFood food) async {}
}

class _PrototypeRemoteStore implements SavedFoodRemoteStore {
  _PrototypeRemoteStore(this.publicFoods);

  final List<SavedFood> publicFoods;

  @override
  SavedFood buildPrivateCopy({
    required SavedFood source,
    required String newFoodId,
    required String ownerUserId,
    required DateTime now,
  }) {
    return source.copyWith(
      foodId: newFoodId,
      ownerUserId: ownerUserId,
      visibility: FoodVisibility.private,
      sourceType: FoodSourceType.copied,
    );
  }

  @override
  Future<SavedFood?> findExactPublicDuplicate({
    required String normalizedName,
    required double baseAmount,
    required FoodUnitType unitType,
    String? excludeOwnerUserId,
    String? excludeFoodId,
  }) async => null;

  @override
  Future<List<SavedFood>> findSimilarPublicFoods({
    required SavedFood food,
    int limit = 20,
  }) async => const [];

  @override
  Future<SavedFood?> getPublicById({
    required String ownerUserId,
    required String foodId,
  }) async => null;

  @override
  Future<SavedFood> publish({
    required String userId,
    required String foodId,
  }) async => throw UnimplementedError();

  @override
  Future<List<SavedFood>> pullAllOwn(String userId) async => const [];

  @override
  Future<void> pushAllOwn(String userId, List<SavedFood> foods) async {}

  @override
  Future<List<SavedFood>> searchPublic({
    required String query,
    int limit = 50,
  }) async => publicFoods;

  @override
  Future<SavedFood> unpublish({
    required String userId,
    required String foodId,
  }) async => throw UnimplementedError();

  @override
  Future<SavedFood> updateOwnRow({
    required String userId,
    required SavedFood food,
  }) async => food;

  @override
  Future<SavedFood> upsertOwnPrivate({
    required String userId,
    required SavedFood food,
  }) async => food;
}

class _PrototypeRatingRepo implements FoodRatingRepositoryBase {
  @override
  Future<void> clearRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  }) async {}

  @override
  Future<FoodRatingSummary?> getSummary({
    required String foodOwnerUserId,
    required String foodId,
  }) async {
    final now = DateTime(2026, 7, 20);
    return switch (foodId) {
      'pub-1' => FoodRatingSummary(
        foodOwnerUserId: foodOwnerUserId,
        foodId: foodId,
        goodCount: 12,
        badCount: 1,
        updatedAt: now,
      ),
      'pub-2' => FoodRatingSummary(
        foodOwnerUserId: foodOwnerUserId,
        foodId: foodId,
        goodCount: 8,
        badCount: 2,
        updatedAt: now,
      ),
      'pub-3' => FoodRatingSummary(
        foodOwnerUserId: foodOwnerUserId,
        foodId: foodId,
        goodCount: 5,
        badCount: 0,
        updatedAt: now,
      ),
      _ => FoodRatingSummary(
        foodOwnerUserId: foodOwnerUserId,
        foodId: foodId,
        goodCount: 3,
        badCount: 1,
        updatedAt: now,
      ),
    };
  }

  @override
  Future<MyFoodRating?> getMyRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  }) async => null;

  @override
  Future<void> setBad({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required String ratingId,
  }) async {}

  @override
  Future<void> setGood({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
    required String ratingId,
  }) async {}
}

Future<AppController> createPrototypeSavedFoodListController() async {
  final now = DateTime(2026, 7, 20);
  final ownFoods = prototypeOwnFoods(now);
  final authRepository = MockAuthenticationRepository(
    currentUser: const AuthUser(
      id: prototypeUserId,
      email: 'prototype@example.com',
    ),
  );
  return AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
    authenticationRepository: authRepository,
    savedFoodRepository: SyncedSavedFoodRepository(
      local: _PrototypeLocalStore(ownFoods),
    ),
  );
}

AppController createPrototypePublicSearchController() {
  final now = DateTime(2026, 7, 20);
  final publicFoods = prototypePublicFoods(now);
  return AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
    savedFoodRepository: SyncedSavedFoodRepository(
      local: _PrototypeLocalStore(const []),
      remote: _PrototypeRemoteStore(publicFoods),
    ),
    foodRatingRepository: _PrototypeRatingRepo(),
  );
}
