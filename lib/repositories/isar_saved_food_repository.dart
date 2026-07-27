import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/entity_enum_codec.dart';
import '../database/schemas.dart';
import '../models/food_status.dart';
import '../models/food_unit_type.dart';
import '../models/saved_food.dart';
import '../utils/food_name_normalizer.dart';
import 'contracts/saved_food_local_store.dart';
import 'contracts/saved_food_repository_base.dart';

/// Isar 上の saved_foods（Local First）。
class IsarSavedFoodRepository extends SavedFoodRepositoryBase
    implements SavedFoodLocalStore {
  IsarSavedFoodRepository(this._isar);

  final Isar _isar;

  @override
  Future<void> savePrivate(SavedFood food) async {
    await _isar.writeTxn(() async {
      await _isar.savedFoodEntitys.put(EntityMapper.toSavedFoodEntity(food));
    });
  }

  Future<void> saveAllPrivate(List<SavedFood> foods) async {
    await _isar.writeTxn(() async {
      await _isar.savedFoodEntitys.putAll(
        foods.map(EntityMapper.toSavedFoodEntity).toList(),
      );
    });
  }

  @Deprecated('Use saveAllPrivate')
  Future<void> saveAll(List<SavedFood> foods) => saveAllPrivate(foods);

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
    final entity = await _isar.savedFoodEntitys
        .filter()
        .foodIdEqualTo(foodId)
        .ownerUserIdEqualTo(ownerUserId)
        .findFirst();
    if (entity == null) {
      return null;
    }
    return EntityMapper.fromSavedFoodEntity(entity);
  }

  @override
  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  }) async {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    final queryBuilder = _isar.savedFoodEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .statusIndexEqualTo(EntityEnumCodec.foodStatusIndex(FoodStatus.active));

    final entities = normalizedQuery.isEmpty
        ? await queryBuilder.findAll()
        : await queryBuilder
              .normalizedNameContains(normalizedQuery, caseSensitive: false)
              .findAll();
    entities.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entities.map(EntityMapper.fromSavedFoodEntity).toList();
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
    await _isar.writeTxn(() async {
      final entity = await _isar.savedFoodEntitys
          .filter()
          .foodIdEqualTo(foodId)
          .ownerUserIdEqualTo(ownerUserId)
          .findFirst();
      if (entity == null) {
        return;
      }
      entity
        ..statusIndex = EntityEnumCodec.foodStatusIndex(FoodStatus.deleted)
        ..deletedAt = deletedAt
        ..updatedAt = deletedAt;
      await _isar.savedFoodEntitys.put(entity);
    });
  }

  @override
  Future<void> replaceAllOwnLocal(
    String ownerUserId,
    List<SavedFood> foods,
  ) async {
    await clearAllLocal();
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
    await _isar.writeTxn(() async {
      await _isar.savedFoodEntitys.clear();
    });
  }

  /// 同期 pull 用: active + deleted 含む全行。
  Future<List<SavedFood>> loadAllOwnIncludingDeleted(String ownerUserId) async {
    final entities = await _isar.savedFoodEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .findAll();
    return entities.map(EntityMapper.fromSavedFoodEntity).toList();
  }
}

/// 後方互換 alias。
typedef SavedFoodRepository = IsarSavedFoodRepository;
