import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/schemas.dart';
import '../models/health_profile_data.dart';
import 'local_write_guard.dart';

/// HealthRepository 実装向けの Workout ローカル保存。
class HealthWorkoutLocalStore {
  HealthWorkoutLocalStore(this._isar);

  final Isar _isar;

  Future<void> saveWorkoutRecords(
    List<HealthWorkoutRecord> records, {
    LocalWriteGuard? mayWrite,
  }) async {
    if (records.isEmpty) {
      return;
    }

    await _isar.writeTxn(() async {
      if (!localWriteAllowed(mayWrite)) {
        return;
      }
      await _isar.healthWorkoutEntitys.putAll(
        records.map(EntityMapper.toHealthWorkoutEntity).toList(),
      );
    });
  }

  Future<List<HealthWorkoutRecord>> loadWorkoutRecords() async {
    final entities = await _isar.healthWorkoutEntitys.where().findAll();
    entities.sort((a, b) => b.startTime.compareTo(a.startTime));
    return entities.map(EntityMapper.fromHealthWorkoutEntity).toList();
  }
}
