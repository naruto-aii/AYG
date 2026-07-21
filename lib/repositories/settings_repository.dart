import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/schemas.dart';
import '../models/app_settings.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';

class SettingsRepository {
  SettingsRepository(this._isar);

  final Isar _isar;

  Future<void> saveNutritionSettings(NutritionSettings settings) async {
    await _isar.writeTxn(() async {
      await _isar.nutritionSettingsEntitys.put(
        EntityMapper.toNutritionSettingsEntity(settings),
      );
    });
  }

  Future<NutritionSettings?> loadNutritionSettings() async {
    final entity = await _isar.nutritionSettingsEntitys.get(1);
    if (entity == null) {
      return null;
    }
    return EntityMapper.fromNutritionSettingsEntity(entity);
  }

  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {
    await _isar.writeTxn(() async {
      await _isar.healthSnapshotEntitys.put(
        EntityMapper.toHealthSnapshotEntity(snapshot),
      );
    });
  }

  Future<HealthSnapshot?> loadHealthSnapshot() async {
    final entity = await _isar.healthSnapshotEntitys.get(1);
    if (entity == null) {
      return null;
    }
    return EntityMapper.fromHealthSnapshotEntity(entity);
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    await _isar.writeTxn(() async {
      await _isar.appSettingsEntitys.put(
        EntityMapper.toAppSettingsEntity(settings),
      );
    });
  }

  Future<AppSettings> loadAppSettings() async {
    final entity = await _isar.appSettingsEntitys.get(1);
    if (entity == null) {
      return const AppSettings();
    }
    return EntityMapper.fromAppSettingsEntity(entity);
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.nutritionSettingsEntitys.clear();
      await _isar.healthSnapshotEntitys.clear();
      await _isar.appSettingsEntitys.clear();
    });
  }
}
