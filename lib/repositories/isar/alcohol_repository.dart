import 'package:isar/isar.dart';

import '../../database/entity_mapper.dart';
import '../../database/schemas.dart';
import '../../models/alcohol_entry.dart';
import '../contracts/alcohol_repository_base.dart';

class AlcoholRepository implements AlcoholRepositoryBase {
  AlcoholRepository(this._isar);

  final Isar _isar;

  @override
  Future<void> save(AlcoholEntry entry) async {
    await _isar.writeTxn(() async {
      await _isar.alcoholEntryEntitys.put(
        EntityMapper.toAlcoholEntryEntity(entry),
      );
    });
  }

  @override
  Future<void> saveAll(List<AlcoholEntry> entries) async {
    await _isar.writeTxn(() async {
      await _isar.alcoholEntryEntitys.putAll(
        entries.map(EntityMapper.toAlcoholEntryEntity).toList(),
      );
    });
  }

  @override
  Future<List<AlcoholEntry>> loadAll() async {
    final entities = await _isar.alcoholEntryEntitys.where().findAll();
    entities.sort((a, b) => b.consumedAt.compareTo(a.consumedAt));
    return entities.map(EntityMapper.fromAlcoholEntryEntity).toList();
  }

  @override
  Future<void> delete(String entryId) async {
    await _isar.writeTxn(() async {
      final entity = await _isar.alcoholEntryEntitys
          .filter()
          .entryIdEqualTo(entryId)
          .findFirst();
      if (entity == null) {
        throw StateError('Alcohol entry not found: $entryId');
      }
      await _isar.alcoholEntryEntitys.delete(entity.id);
    });
  }

  @override
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.alcoholEntryEntitys.clear();
    });
  }
}
