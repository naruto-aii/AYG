import 'package:isar/isar.dart';

import '../database/schemas.dart';
import '../repositories/contracts/exercise_repository_base.dart';
import '../repositories/contracts/food_repository_base.dart';
import '../repositories/contracts/meal_template_repository_base.dart';
import '../repositories/contracts/settings_repository_base.dart';
import '../repositories/contracts/user_repository_base.dart';
import '../repositories/contracts/weight_repository_base.dart';
import '../repositories/meal_template_repository.dart';
import '../repositories/saved_food_repository.dart';
import 'local_user_data_clearer_base.dart';

/// ログインユーザー切替時に Isar のユーザーデータを消去する。
class LocalUserDataClearer implements LocalUserDataClearerBase {
  LocalUserDataClearer({
    required Isar isar,
    required UserRepositoryBase userRepository,
    required SettingsRepositoryBase settingsRepository,
    required FoodRepositoryBase foodRepository,
    required ExerciseRepositoryBase exerciseRepository,
    required WeightRepositoryBase weightRepository,
    SavedFoodRepository? savedFoodRepository,
    MealTemplateRepository? mealTemplateRepository,
  }) : _isar = isar,
       _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _weightRepository = weightRepository,
       _savedFoodRepository = savedFoodRepository,
       _mealTemplateRepository = mealTemplateRepository;

  final Isar _isar;
  final UserRepositoryBase _userRepository;
  final SettingsRepositoryBase _settingsRepository;
  final FoodRepositoryBase _foodRepository;
  final ExerciseRepositoryBase _exerciseRepository;
  final WeightRepositoryBase _weightRepository;
  final SavedFoodRepository? _savedFoodRepository;
  final MealTemplateRepository? _mealTemplateRepository;

  @override
  Future<void> clearAll() async {
    await _userRepository.clearAll();
    await _settingsRepository.clearAll();
    await _foodRepository.clearAll();
    await _exerciseRepository.clearAll();
    await _weightRepository.clearAll();
    await _savedFoodRepository?.clearAll();
    await _mealTemplateRepository?.clearAll();

    await _isar.writeTxn(() async {
      await _isar.healthWorkoutEntitys.clear();
    });
  }
}
