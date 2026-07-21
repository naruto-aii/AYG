import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/schemas.dart';
import '../models/food_entry.dart';
import 'contracts/food_repository_base.dart';

class FoodRepository implements FoodRepositoryBase {
  FoodRepository(this._isar);

  final Isar _isar;

  @override
  Future<void> save(FoodEntry entry) async {
    await _isar.writeTxn(() async {
      await _isar.foodEntryEntitys.put(EntityMapper.toFoodEntryEntity(entry));
    });
  }

  @override
  Future<void> saveAll(List<FoodEntry> entries) async {
    await _isar.writeTxn(() async {
      await _isar.foodEntryEntitys.putAll(
        entries.map(EntityMapper.toFoodEntryEntity).toList(),
      );
    });
  }

  @override
  Future<List<FoodEntry>> loadAll() async {
    final entities = await _isar.foodEntryEntitys.where().findAll();
    entities.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return entities.map(EntityMapper.fromFoodEntryEntity).toList();
  }

  @override
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

  @override
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.foodEntryEntitys.clear();
    });
  }
}
