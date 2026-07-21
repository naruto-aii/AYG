import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/schemas.dart';
import '../models/exercise_entry.dart';
import 'contracts/exercise_repository_base.dart';

class ExerciseRepository implements ExerciseRepositoryBase {
  ExerciseRepository(this._isar);

  final Isar _isar;

  @override
  Future<void> save(ExerciseEntry entry) async {
    await _isar.writeTxn(() async {
      await _isar.exerciseEntryEntitys.put(
        EntityMapper.toExerciseEntryEntity(entry),
      );
    });
  }

  @override
  Future<void> saveAll(List<ExerciseEntry> entries) async {
    await _isar.writeTxn(() async {
      await _isar.exerciseEntryEntitys.putAll(
        entries.map(EntityMapper.toExerciseEntryEntity).toList(),
      );
    });
  }

  @override
  Future<List<ExerciseEntry>> loadAll() async {
    final entities = await _isar.exerciseEntryEntitys.where().findAll();
    entities.sort((a, b) => b.loggedAt.compareTo(a.loggedAt));
    return entities.map(EntityMapper.fromExerciseEntryEntity).toList();
  }

  @override
  Future<void> delete(String entryId) async {
    await _isar.writeTxn(() async {
      final entity = await _isar.exerciseEntryEntitys
          .filter()
          .entryIdEqualTo(entryId)
          .findFirst();
      if (entity != null) {
        await _isar.exerciseEntryEntitys.delete(entity.id);
      }
    });
  }

  @override
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.exerciseEntryEntitys.clear();
    });
  }
}
