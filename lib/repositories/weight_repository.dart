import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/schemas.dart';
import '../models/health_profile_data.dart';
import '../models/weight_entry.dart';

class WeightRepository {
  WeightRepository(this._isar);

  final Isar _isar;

  Future<void> save(WeightEntry entry) async {
    await _isar.writeTxn(() async {
      await _isar.weightEntryEntitys.put(
        EntityMapper.toWeightEntryEntity(entry),
      );
    });
  }

  Future<List<WeightEntry>> loadAll() async {
    final entities = await _isar.weightEntryEntitys.where().findAll();
    entities.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return entities.map(EntityMapper.fromWeightEntryEntity).toList();
  }

  Future<double?> latestWeight({WeightSource? preferredSource}) async {
    final entries = await loadAll();
    if (entries.isEmpty) {
      return null;
    }

    if (preferredSource != null) {
      for (final entry in entries) {
        if (entry.source == preferredSource) {
          return entry.weightKg;
        }
      }
    }

    return entries.first.weightKg;
  }

  Future<List<WeightRecord>> loadWeightRecords() async {
    final entries = await loadAll();
    return entries.map(weightEntryToRecord).toList();
  }

  Future<void> saveWeightRecord(WeightRecord record) async {
    await save(weightEntryFromRecord(record));
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.weightEntryEntitys.clear();
    });
  }
}
