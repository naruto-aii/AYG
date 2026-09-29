import 'package:ayg/models/food_rating.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/public_food_publish_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/contracts/food_rating_repository_base.dart';
import 'package:ayg/repositories/contracts/saved_food_local_store.dart';
import 'package:ayg/repositories/contracts/saved_food_remote_store.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/repositories/synced_saved_food_repository.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeLocalStore implements SavedFoodLocalStore {
  SavedFood? stored;

  @override
  Future<void> clearAllLocal() async {}

  @override
  Future<SavedFood?> getOwn({
    required String ownerUserId,
    required String foodId,
  }) async => stored;

  @override
  Future<List<SavedFood>> loadAllOwnIncludingDeleted(
    String ownerUserId,
  ) async => stored == null ? [] : [stored!];

  @override
  Future<void> replaceAllOwnLocal(
    String ownerUserId,
    List<SavedFood> foods,
  ) async {
    stored = foods.isEmpty ? null : foods.first;
  }

  @override
  Future<void> saveAllPrivate(List<SavedFood> foods) async {
    if (foods.isNotEmpty) {
      stored = foods.first;
    }
  }

  @override
  Future<void> savePrivate(SavedFood food) async {
    stored = food;
  }

  @override
  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  }) async => stored == null ? [] : [stored!];

  @override
  Future<void> softDelete({
    required String ownerUserId,
    required String foodId,
    required DateTime deletedAt,
  }) async {}

  @override
  Future<void> updateOwn(SavedFood food) async {
    stored = food;
  }
}

SavedFood _sampleFood(String userId, String foodId) {
  return SavedFood(
    foodId: foodId,
    ownerUserId: AppController.localOwnerUserId,
    name: 'Food',
    normalizedName: 'food',
    baseAmount: 100,
    unitType: FoodUnitType.g,
    servingUnitLabel: 'g',
    kcalPerBase: 165,
    proteinPerBase: 10,
    fatPerBase: 5,
    carbPerBase: 20,
    visibility: FoodVisibility.private,
    status: FoodStatus.active,
    sourceType: FoodSourceType.manual,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

class _FakeRemoteStore implements SavedFoodRemoteStore {
  Object? publishError;

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
      createdAt: now,
      updatedAt: now,
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
  }) async {
    if (publishError != null) {
      throw publishError!;
    }
    return _sampleFood(
      userId,
      foodId,
    ).copyWith(visibility: FoodVisibility.public);
  }

  @override
  Future<List<SavedFood>> pullAllOwn(String userId) async => const [];

  @override
  Future<void> pushAllOwn(String userId, List<SavedFood> foods) async {}

  @override
  Future<List<SavedFood>> searchPublic({
    required String query,
    int limit = 50,
  }) async => const [];

  @override
  Future<SavedFood> unpublish({
    required String userId,
    required String foodId,
  }) async =>
      _sampleFood(userId, foodId).copyWith(visibility: FoodVisibility.private);

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

class _PublishRemoteStore extends _FakeRemoteStore {
  _PublishRemoteStore({
    this.duplicate,
    this.similar = const [],
    Object? publishError,
  }) {
    this.publishError = publishError;
  }

  final SavedFood? duplicate;
  final List<SavedFood> similar;

  @override
  Future<SavedFood?> findExactPublicDuplicate({
    required String normalizedName,
    required double baseAmount,
    required FoodUnitType unitType,
    String? excludeOwnerUserId,
    String? excludeFoodId,
  }) async => duplicate;

  @override
  Future<List<SavedFood>> findSimilarPublicFoods({
    required SavedFood food,
    int limit = 20,
  }) async => similar;
}

class _NoOpRatingRepository implements FoodRatingRepositoryBase {
  @override
  Future<void> clearRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  }) async {}

  @override
  Future<MyFoodRating?> getMyRating({
    required String foodOwnerUserId,
    required String foodId,
    required String raterUserId,
  }) async => null;

  @override
  Future<FoodRatingSummary?> getSummary({
    required String foodOwnerUserId,
    required String foodId,
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
  group('AppController publish', () {
    late _FakeLocalStore local;
    late SyncedSavedFoodRepository repository;
    late AppController controller;

    setUp(() {
      local = _FakeLocalStore()..stored = _sampleFood('ignored', 'food-1');
      repository = SyncedSavedFoodRepository(
        local: local,
        remote: _PublishRemoteStore(),
      );
      controller = AppController(
        savedFoodRepository: repository,
        foodRatingRepository: _NoOpRatingRepository(),
      );
    });

    tearDown(() => controller.dispose());

    test('checkPublicDuplicate returns match', () async {
      final duplicate = _sampleFood(
        'other',
        'dup',
      ).copyWith(visibility: FoodVisibility.public);
      repository = SyncedSavedFoodRepository(
        local: local,
        remote: _PublishRemoteStore(duplicate: duplicate),
      );
      controller = AppController(
        savedFoodRepository: repository,
        foodRatingRepository: _NoOpRatingRepository(),
      );

      final match = await controller.checkPublicDuplicate(local.stored!);
      expect(match, isA<PublicFoodPublishMatch>());
    });

    test('publishSavedFood updates local only after RPC success', () async {
      final published = await controller.publishSavedFood('food-1');
      expect(published.visibility, FoodVisibility.public);
      expect(local.stored?.visibility, FoodVisibility.public);
    });

    test('publish failure keeps private local state', () async {
      repository = SyncedSavedFoodRepository(
        local: local,
        remote: _PublishRemoteStore(
          publishError: const PublishSavedFoodException(
            kind: PublishFailureKind.duplicate,
            message: 'duplicate',
          ),
        ),
      );
      controller = AppController(
        savedFoodRepository: repository,
        foodRatingRepository: _NoOpRatingRepository(),
      );

      await expectLater(
        controller.publishSavedFood('food-1'),
        throwsA(isA<PublishSavedFoodException>()),
      );
      expect(local.stored?.visibility, FoodVisibility.private);
    });

    test('blocks concurrent publish operations', () async {
      controller = AppController(
        savedFoodRepository: repository,
        foodRatingRepository: _NoOpRatingRepository(),
      );

      final first = controller.publishSavedFood('food-1');
      expect(
        () => controller.publishSavedFood('food-1'),
        throwsA(isA<StateError>()),
      );
      await first;
    });
  });
}
