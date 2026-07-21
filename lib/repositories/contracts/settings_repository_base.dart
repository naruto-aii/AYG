import '../../models/app_settings.dart';
import '../../models/health_snapshot.dart';
import '../../models/nutrition_settings.dart';

abstract class SettingsRepositoryBase {
  Future<void> saveNutritionSettings(NutritionSettings settings);

  Future<NutritionSettings?> loadNutritionSettings();

  Future<void> saveHealthSnapshot(HealthSnapshot snapshot);

  Future<HealthSnapshot?> loadHealthSnapshot();

  Future<void> saveAppSettings(AppSettings settings);

  Future<AppSettings> loadAppSettings();

  Future<void> clearAll();
}
