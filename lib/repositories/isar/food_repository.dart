import 'package:isar/isar.dart';

import '../../database/entity_mapper.dart';
import '../../database/schemas.dart';
import '../../models/food_entry.dart';
import '../contracts/food_repository_base.dart';

class FoodRepository implements FoodRepositoryBase {
  FoodRepository(this._isar);

  final Isar _isar;

  Future<void> save(FoodEntry entry) async {
    await _isar.writeTxn(() async {
      await _isar.foodEntryEntitys.put(EntityMapper.toFoodEntryEntity(entry));
    });
  }

  Future<void> saveAll(List<FoodEntry> entries) async {
    await _isar.writeTxn(() async {
      await _isar.foodEntryEntitys.putAll(
        entries.map(EntityMapper.toFoodEntryEntity).toList(),
      );
    });
  }

  Future<List<FoodEntry>> loadAll() async {
    final List<FoodEntryEntity> entities;
    try {
      entities = await _isar.foodEntryEntitys.where().findAll();
    } on Object {
      return _loadAllSkippingUnreadable();
    }
    return _entriesFrom(entities);
  }

  Future<List<FoodEntry>> _loadAllSkippingUnreadable() async {
    final ids = await _isar.foodEntryEntitys.where().idProperty().findAll();
    final entities = <FoodEntryEntity>[];
    for (final id in ids) {
      try {
        final entity = await _isar.foodEntryEntitys.get(id);
        if (entity != null) {
          entities.add(entity);
        }
      } on Object {
        // この1件だけ飛ばす。保存そのものは続ける。
      }
    }
    return _entriesFrom(entities);
  }

  List<FoodEntry> _entriesFrom(List<FoodEntryEntity> entities) {
    final readable = entities.where(isReadableStoredFoodEntry).toList()
      ..sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return readable.map(EntityMapper.fromFoodEntryEntity).toList();
  }

  Future<void> delete(String entryId) async {
    await _isar.writeTxn(() async {
      final entity = await _isar.foodEntryEntitys
          .filter()
          .entryIdEqualTo(entryId)
          .findFirst();
      if (entity != null) {
        await _isar.foodEntryEntitys.delete(entity.id);
      }
    });
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.foodEntryEntitys.clear();
    });
  }

  Future<void> replaceAll(List<FoodEntry> entries) async {
    await _isar.writeTxn(() async {
      await _isar.foodEntryEntitys.clear();
      if (entries.isEmpty) {
        return;
      }
      await _isar.foodEntryEntitys.putAll(
        entries.map(EntityMapper.toFoodEntryEntity).toList(),
      );
    });
  }

  Future<FoodEntry?> findById(String entryId) async {
    final entity = await _isar.foodEntryEntitys
        .filter()
        .entryIdEqualTo(entryId)
        .findFirst();
    if (entity == null || !isReadableStoredFoodEntry(entity)) {
      return null;
    }
    return EntityMapper.fromFoodEntryEntity(entity);
  }
}
