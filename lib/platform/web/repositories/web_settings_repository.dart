import '../../../models/app_settings.dart';
import '../../../models/health_snapshot.dart';
import '../../../models/nutrition_settings.dart';
import '../../../repositories/contracts/settings_repository_base.dart';

class WebSettingsRepository implements SettingsRepositoryBase {
  NutritionSettings? _nutritionSettings;
  HealthSnapshot? _healthSnapshot;
  AppSettings _appSettings = const AppSettings();

  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async {
    _nutritionSettings = settings;
  }

  @override
  Future<NutritionSettings?> loadNutritionSettings() async =>
      _nutritionSettings;

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {
    _healthSnapshot = snapshot;
  }

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => _healthSnapshot;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {
    _appSettings = settings;
  }

  @override
  Future<AppSettings> loadAppSettings() async => _appSettings;

  @override
  Future<void> clearAll() async {
    _nutritionSettings = null;
    _healthSnapshot = null;
    _appSettings = const AppSettings();
  }
}
