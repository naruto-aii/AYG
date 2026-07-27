import 'dart:io';

import 'package:ayg/database/isar_service.dart';
import 'package:ayg/repositories/exercise_repository.dart';
import 'package:ayg/repositories/food_repository.dart';
import 'package:ayg/repositories/meal_template_repository.dart';
import 'package:ayg/repositories/saved_food_repository.dart';
import 'package:ayg/repositories/settings_repository.dart';
import 'package:ayg/repositories/unsupported_health_repository.dart';
import 'package:ayg/repositories/user_repository.dart';
import 'package:ayg/repositories/weight_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

class IsarTestHarness {
  IsarTestHarness._({
    required this.directory,
    required this.isar,
    required this.weightRepository,
    required this.userRepository,
    required this.settingsRepository,
    required this.foodRepository,
    required this.exerciseRepository,
    required this.savedFoodRepository,
    required this.mealTemplateRepository,
    required this.healthRepository,
  });

  final Directory directory;
  final Isar isar;
  final WeightRepository weightRepository;
  final UserRepository userRepository;
  final SettingsRepository settingsRepository;
  final FoodRepository foodRepository;
  final ExerciseRepository exerciseRepository;
  final SavedFoodRepository savedFoodRepository;
  final MealTemplateRepository mealTemplateRepository;
  final UnsupportedHealthRepository healthRepository;

  static Future<IsarTestHarness> create() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await IsarService.close();
    final directory = await Directory.systemTemp.createTemp('ayg_isar_test_');
    final isar = await IsarService.openForTesting(directory.path);
    final weightRepository = WeightRepository(isar);
    return IsarTestHarness._(
      directory: directory,
      isar: isar,
      weightRepository: weightRepository,
      userRepository: UserRepository(isar),
      settingsRepository: SettingsRepository(isar),
      foodRepository: FoodRepository(isar),
      exerciseRepository: ExerciseRepository(isar),
      savedFoodRepository: SavedFoodRepository(isar),
      mealTemplateRepository: MealTemplateRepository(isar),
      healthRepository: UnsupportedHealthRepository(
        weightRepository: weightRepository,
        isar: isar,
      ),
    );
  }

  Future<void> dispose() async {
    await IsarService.close();
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}

Future<IsarTestHarness> setUpIsarHarness() async {
  final harness = await IsarTestHarness.create();
  addTearDown(harness.dispose);
  return harness;
}
