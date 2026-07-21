import 'package:isar/isar.dart';

import '../database/entity_mapper.dart';
import '../database/schemas.dart';
import '../models/app_settings.dart';
import '../models/health_snapshot.dart';
import '../models/nutrition_settings.dart';
import 'contracts/settings_repository_base.dart';

class SettingsRepository implements SettingsRepositoryBase {
  SettingsRepository(this._isar);

  final Isar _isar;

  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async {
    await _isar.writeTxn(() async {
      await _isar.nutritionSettingsEntitys.put(
        EntityMapper.toNutritionSettingsEntity(settings),
      );
    });
  }

  @override
  Future<NutritionSettings?> loadNutritionSettings() async {
    final entity = await _isar.nutritionSettingsEntitys.get(1);
    if (entity == null) {
      return null;
    }
    return EntityMapper.fromNutritionSettingsEntity(entity);
  }

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {
    await _isar.writeTxn(() async {
      await _isar.healthSnapshotEntitys.put(
        EntityMapper.toHealthSnapshotEntity(snapshot),
      );
    });
  }

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async {
    final entity = await _isar.healthSnapshotEntitys.get(1);
    if (entity == null) {
      return null;
    }
    return EntityMapper.fromHealthSnapshotEntity(entity);
  }

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    await _isar.writeTxn(() async {
      await _isar.appSettingsEntitys.put(
        EntityMapper.toAppSettingsEntity(settings),
      );
    });
  }

  @override
  Future<AppSettings> loadAppSettings() async {
    final entity = await _isar.appSettingsEntitys.get(1);
    if (entity == null) {
      return const AppSettings();
    }
    return EntityMapper.fromAppSettingsEntity(entity);
  }

  @override
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.nutritionSettingsEntitys.clear();
      await _isar.healthSnapshotEntitys.clear();
      await _isar.appSettingsEntitys.clear();
    });
  }
}
