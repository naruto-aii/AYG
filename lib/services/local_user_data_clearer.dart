import 'package:isar/isar.dart';

import '../database/schemas.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/food_repository.dart';
import '../repositories/meal_template_repository.dart';
import '../repositories/saved_food_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/weight_repository.dart';

/// ログインユーザー切替時に Isar のユーザーデータを消去する。
class LocalUserDataClearer {
  LocalUserDataClearer({
    required Isar isar,
    required UserRepository userRepository,
    required SettingsRepository settingsRepository,
    required FoodRepository foodRepository,
    required ExerciseRepository exerciseRepository,
    required WeightRepository weightRepository,
    required SavedFoodRepository savedFoodRepository,
    required MealTemplateRepository mealTemplateRepository,
  }) : _isar = isar,
       _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _weightRepository = weightRepository,
       _savedFoodRepository = savedFoodRepository,
       _mealTemplateRepository = mealTemplateRepository;

  final Isar _isar;
  final UserRepository _userRepository;
  final SettingsRepository _settingsRepository;
  final FoodRepository _foodRepository;
  final ExerciseRepository _exerciseRepository;
  final WeightRepository _weightRepository;
  final SavedFoodRepository _savedFoodRepository;
  final MealTemplateRepository _mealTemplateRepository;

  Future<void> clearAll() async {
    await _userRepository.clearAll();
    await _settingsRepository.clearAll();
    await _foodRepository.clearAll();
    await _exerciseRepository.clearAll();
    await _weightRepository.clearAll();
    await _savedFoodRepository.clearAll();
    await _mealTemplateRepository.clearAll();

    await _isar.writeTxn(() async {
      await _isar.healthWorkoutEntitys.clear();
    });
  }
}
