import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_status.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/food_visibility.dart';
import 'package:ayg/models/moderation_status.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/repositories/contracts/saved_food_local_store.dart';
import 'package:ayg/repositories/contracts/saved_food_remote_store.dart';
import 'package:ayg/repositories/exceptions/food_master_exceptions.dart';
import 'package:ayg/repositories/synced_saved_food_repository.dart';
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
  }) async {
    stored = stored?.copyWith(
      status: FoodStatus.deleted,
      deletedAt: deletedAt,
      updatedAt: deletedAt,
    );
  }

  @override
  Future<void> updateOwn(SavedFood food) async {
    stored = food;
  }
}

class _FakeRemoteStore implements SavedFoodRemoteStore {
  Object? publishError;
  Object? upsertError;

  bool upsertCalled = false;

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
  Future<SavedFood?> getPublicById({
    required String ownerUserId,
    required String foodId,
  }) async => null;

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
  }) async {
    upsertCalled = true;
    if (upsertError != null) {
      throw upsertError!;
    }
    return food;
  }
}

SavedFood _sampleFood(String userId, String foodId) {
  return SavedFood(
    foodId: foodId,
    ownerUserId: userId,
    name: 'Food',
    normalizedName: 'food',
    baseAmount: 100,
    unitType: FoodUnitType.g,
    visibility: FoodVisibility.private,
    status: FoodStatus.active,
    moderationStatus: ModerationStatus.none,
    sourceType: FoodSourceType.manual,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('SyncedSavedFoodRepository', () {
    test('publish updates local after remote success', () async {
      final local = _FakeLocalStore();
      final remote = _FakeRemoteStore();
      final repo = SyncedSavedFoodRepository(local: local, remote: remote);

      final result = await repo.publish(ownerUserId: 'u1', foodId: 'f1');

      expect(result.visibility, FoodVisibility.public);
      expect(local.stored?.visibility, FoodVisibility.public);
    });

    test('publish failure does not update local', () async {
      final local = _FakeLocalStore()..stored = _sampleFood('u1', 'f1');
      final remote = _FakeRemoteStore()
        ..publishError = const PublishSavedFoodException(
          kind: PublishFailureKind.duplicate,
          message: 'duplicate',
        );
      final repo = SyncedSavedFoodRepository(local: local, remote: remote);

      await expectLater(
        repo.publish(ownerUserId: 'u1', foodId: 'f1'),
        throwsA(isA<PublishSavedFoodException>()),
      );
      expect(local.stored?.visibility, FoodVisibility.private);
    });

    test('searchPublic requires remote', () async {
      final repo = SyncedSavedFoodRepository(local: _FakeLocalStore());
      await expectLater(
        repo.searchPublic(query: 'rice'),
        throwsA(isA<FoodMasterNetworkException>()),
      );
    });

    test('savePrivate writes remote before local', () async {
      final local = _FakeLocalStore();
      final remote = _FakeRemoteStore();
      final repo = SyncedSavedFoodRepository(local: local, remote: remote);

      await repo.savePrivate(_sampleFood('u1', 'f1'));

      expect(remote.upsertCalled, isTrue);
      expect(local.stored, isNotNull);
    });

    test('savePrivate remote failure does not persist locally', () async {
      final local = _FakeLocalStore();
      final remote = _FakeRemoteStore()
        ..upsertError = const FoodMasterPermissionException('denied');
      final repo = SyncedSavedFoodRepository(local: local, remote: remote);

      await expectLater(
        repo.savePrivate(_sampleFood('u1', 'f1')),
        throwsA(isA<FoodMasterPermissionException>()),
      );
      expect(local.stored, isNull);
    });

    test('softDelete writes remote before local', () async {
      final local = _FakeLocalStore()..stored = _sampleFood('u1', 'f1');
      final remote = _FakeRemoteStore();
      final repo = SyncedSavedFoodRepository(local: local, remote: remote);
      final deletedAt = DateTime.utc(2026, 2, 1);

      await repo.softDelete(
        ownerUserId: 'u1',
        foodId: 'f1',
        deletedAt: deletedAt,
      );

      expect(local.stored?.status, FoodStatus.deleted);
    });

    test('updateOwn writes remote before local', () async {
      final local = _FakeLocalStore()
        ..stored = _sampleFood('u1', 'f1').copyWith(
          visibility: FoodVisibility.public,
          kcalPerBase: 100,
          version: 2,
        );
      final remote = _FakeRemoteStore();
      final repo = SyncedSavedFoodRepository(local: local, remote: remote);

      await repo.updateOwn(
        local.stored!.copyWith(
          kcalPerBase: 110,
          updatedAt: DateTime.utc(2026, 2, 1),
        ),
      );

      expect(local.stored?.kcalPerBase, 110);
      expect(local.stored?.version, 3);
    });
  });
}
