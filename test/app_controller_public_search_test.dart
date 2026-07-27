import 'package:ayg/models/food_rating.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/contracts/food_rating_repository_base.dart';
import 'package:ayg/repositories/contracts/saved_food_local_store.dart';
import 'package:ayg/repositories/contracts/saved_food_remote_store.dart';
import 'package:ayg/repositories/synced_saved_food_repository.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocalStore implements SavedFoodLocalStore {
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
  ) async => const [];

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
  }) async => const [];

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<void> updateOwn(SavedFood food) async {}
}

class _FakeRemoteStore implements SavedFoodRemoteStore {
  _FakeRemoteStore({
    required this.publicFoods,
    this.publicById,
    SavedFood? copyResult,
  }) : copyResult = copyResult;

  final List<SavedFood> publicFoods;
  final SavedFood? Function(String ownerUserId, String foodId)? publicById;
  SavedFood? copyResult;
  SavedFood? lastCopiedSource;

  @override
  SavedFood buildPrivateCopy({
    required SavedFood source,
    required String newFoodId,
    required String ownerUserId,
    required DateTime now,
  }) {
    lastCopiedSource = source;
    return copyResult ??
        source.copyWith(
          foodId: newFoodId,
          ownerUserId: ownerUserId,
          visibility: FoodVisibility.private,
          sourceType: FoodSourceType.copied,
          copiedFromFoodId: source.foodId,
          copiedFromOwnerUserId: source.ownerUserId,
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
  }) async => publicById?.call(ownerUserId, foodId);

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

class _FakeRatingRepo implements FoodRatingRepositoryBase {
  _FakeRatingRepo(this.summaries);

  final Map<String, FoodRatingSummary> summaries;

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
  }) async => summaries['$foodOwnerUserId:$foodId'];

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

void main() {
  final now = DateTime(2026, 7, 20);

  SavedFood publicFood({
    required String foodId,
    required String ownerUserId,
    String name = 'Public Rice',
    int version = 2,
  }) {
    return SavedFood(
      foodId: foodId,
      ownerUserId: ownerUserId,
      name: name,
      normalizedName: name.toLowerCase(),
      baseAmount: 100,
      unitType: FoodUnitType.g,
      kcalPerBase: 130,
      visibility: FoodVisibility.public,
      status: FoodStatus.active,
      version: version,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('AppController public search', () {
    test('searchPublicSavedFoods returns ranked matches', () async {
      final remote = _FakeRemoteStore(
        publicFoods: [publicFood(foodId: 'f1', ownerUserId: 'u1')],
      );
      final repo = SyncedSavedFoodRepository(
        local: _FakeLocalStore(),
        remote: remote,
      );
      final controller = AppController(
        savedFoodRepository: repo,
        foodRatingRepository: _FakeRatingRepo(const {}),
      );

      final results = await controller.searchPublicSavedFoods('public rice');
      expect(results, hasLength(1));
      expect(results.first, isA<PublicFoodSearchMatch>());
    });

    test('search failure returns empty list without throwing', () async {
      final remote = _ThrowingRemoteStore();
      final repo = SyncedSavedFoodRepository(
        local: _FakeLocalStore(),
        remote: remote,
      );
      final controller = AppController(savedFoodRepository: repo);

      final results = await controller.searchPublicSavedFoods('rice');
      expect(results, isEmpty);
    });

    test('copyPublicFoodToPrivate creates private copy', () async {
      final source = publicFood(foodId: 'src', ownerUserId: 'other');
      final remote = _FakeRemoteStore(publicFoods: [source]);
      final repo = SyncedSavedFoodRepository(
        local: _FakeLocalStore(),
        remote: remote,
      );
      final controller = AppController(savedFoodRepository: repo);

      final copy = await controller.copyPublicFoodToPrivate(source);
      expect(copy.visibility, FoodVisibility.private);
      expect(copy.sourceType, FoodSourceType.copied);
      expect(copy.copiedFromFoodId, 'src');
      expect(copy.ownerUserId, AppController.localOwnerUserId);
    });

    test('selectSavedFoodForEntry includes version snapshot', () {
      final controller = AppController();
      final food = publicFood(foodId: 'f1', ownerUserId: 'u1', version: 5);
      final selection = controller.selectSavedFoodForEntry(food);
      expect(selection.sourceSavedFoodVersion, 5);
      expect(selection.savedFoodId, 'f1');
      expect(selection.sourceFoodOwnerUserId, 'u1');
    });

    test('canEditSavedFood rejects other users food', () {
      final controller = AppController();
      final own = publicFood(
        foodId: 'f1',
        ownerUserId: AppController.localOwnerUserId,
      );
      final other = publicFood(foodId: 'f2', ownerUserId: 'other-user');
      expect(controller.canEditSavedFood(own), isTrue);
      expect(controller.canEditSavedFood(other), isFalse);
    });
  });
}

class _ThrowingRemoteStore extends _FakeRemoteStore {
  _ThrowingRemoteStore() : super(publicFoods: const []);

  @override
  Future<List<SavedFood>> searchPublic({
    required String query,
    int limit = 50,
  }) async {
    throw Exception('network');
  }
}
