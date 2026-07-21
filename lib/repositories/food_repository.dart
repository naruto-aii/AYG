import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/schemas.dart';
import '../models/food_entry.dart';

class FoodRepository {
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
    final entities = await _isar.foodEntryEntitys.where().findAll();
    entities.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return entities.map(EntityMapper.fromFoodEntryEntity).toList();
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
}
