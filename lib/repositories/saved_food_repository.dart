import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/entity_enum_codec.dart';
import '../database/schemas.dart';
import '../models/food_status.dart';
import '../models/saved_food.dart';
import '../utils/food_name_normalizer.dart';
import 'contracts/saved_food_repository_base.dart';

class SavedFoodRepository implements SavedFoodRepositoryBase {
  SavedFoodRepository(this._isar);

  final Isar _isar;

  @override
  Future<void> save(SavedFood food) async {
    await _isar.writeTxn(() async {
      await _isar.savedFoodEntitys.put(EntityMapper.toSavedFoodEntity(food));
    });
  }

  @override
  Future<void> saveAll(List<SavedFood> foods) async {
    await _isar.writeTxn(() async {
      await _isar.savedFoodEntitys.putAll(
        foods.map(EntityMapper.toSavedFoodEntity).toList(),
      );
    });
  }

  @override
  Future<SavedFood?> getById({
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
  Future<List<SavedFood>> getAllOwn(String ownerUserId) async {
    final entities = await _isar.savedFoodEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .statusIndexEqualTo(EntityEnumCodec.foodStatusIndex(FoodStatus.active))
        .findAll();
    entities.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return entities.map(EntityMapper.fromSavedFoodEntity).toList();
  }

  @override
  Future<List<SavedFood>> searchOwn({
    required String ownerUserId,
    required String query,
  }) async {
    final normalizedQuery = FoodNameNormalizer.normalize(query);
    if (normalizedQuery.isEmpty) {
      return getAllOwn(ownerUserId);
    }

    final entities = await _isar.savedFoodEntitys
        .filter()
        .ownerUserIdEqualTo(ownerUserId)
        .statusIndexEqualTo(EntityEnumCodec.foodStatusIndex(FoodStatus.active))
        .normalizedNameContains(normalizedQuery, caseSensitive: false)
        .findAll();
    entities.sort((a, b) => a.normalizedName.compareTo(b.normalizedName));
    return entities.map(EntityMapper.fromSavedFoodEntity).toList();
  }

  @override
  Future<void> update(SavedFood food) async {
    await save(food);
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
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.savedFoodEntitys.clear();
    });
  }
}
