import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'schemas.dart';

/// Isar データベースの初期化・管理。
class IsarService {
  IsarService._();

  static Isar? _instance;

  static Isar get instance {
    final isar = _instance;
    if (isar == null) {
      throw StateError(
        'Isar has not been opened. Call IsarService.open first.',
      );
    }
    return isar;
  }

  static Future<Isar> open({String? directory}) async {
    if (_instance != null && _instance!.isOpen) {
      return _instance!;
    }

    final dir = directory ?? (await getApplicationDocumentsDirectory()).path;
    _instance = await Isar.open(
      [
        UserProfileEntitySchema,
        GoalEntitySchema,
        NutritionSettingsEntitySchema,
        FoodEntryEntitySchema,
        SavedFoodEntitySchema,
        MealTemplateEntitySchema,
        MealTemplateItemEntitySchema,
        ExerciseEntryEntitySchema,
        WeightEntryEntitySchema,
        HealthSnapshotEntitySchema,
        AppSettingsEntitySchema,
        HealthWorkoutEntitySchema,
      ],
      directory: dir,
      name: 'ayg',
    );
    return _instance!;
  }

  static Future<Isar> openForTesting(String directory) {
    return open(directory: directory);
  }

  static Future<void> close() async {
    await _instance?.close();
    _instance = null;
  }
}
