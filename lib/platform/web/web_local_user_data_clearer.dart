import '../../repositories/contracts/exercise_repository_base.dart';
import '../../repositories/contracts/food_repository_base.dart';
import '../../repositories/contracts/meal_template_repository_base.dart';
import '../../repositories/contracts/settings_repository_base.dart';
import '../../repositories/contracts/user_repository_base.dart';
import '../../repositories/contracts/weight_repository_base.dart';
import '../../repositories/contracts/saved_food_local_store.dart';
import '../../services/local_user_data_clearer_base.dart';
import '../web/web_health_workout_store.dart';

/// Web向けローカルデータ消去（Isar非依存）。
class LocalUserDataClearer implements LocalUserDataClearerBase {
  LocalUserDataClearer({
    required UserRepositoryBase userRepository,
    required SettingsRepositoryBase settingsRepository,
    required FoodRepositoryBase foodRepository,
    required ExerciseRepositoryBase exerciseRepository,
    required WeightRepositoryBase weightRepository,
    required SavedFoodLocalStore savedFoodRepository,
    required MealTemplateRepositoryBase mealTemplateRepository,
    WebHealthWorkoutStore? workoutStore,
  }) : _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _weightRepository = weightRepository,
       _savedFoodRepository = savedFoodRepository,
       _mealTemplateRepository = mealTemplateRepository,
       _workoutStore = workoutStore ?? WebHealthWorkoutStore();

  final UserRepositoryBase _userRepository;
  final SettingsRepositoryBase _settingsRepository;
  final FoodRepositoryBase _foodRepository;
  final ExerciseRepositoryBase _exerciseRepository;
  final WeightRepositoryBase _weightRepository;
  final SavedFoodLocalStore _savedFoodRepository;
  final MealTemplateRepositoryBase _mealTemplateRepository;
  final WebHealthWorkoutStore _workoutStore;

  @override
  Future<void> clearAll() async {
    await _userRepository.clearAll();
    await _settingsRepository.clearAll();
    await _foodRepository.clearAll();
    await _exerciseRepository.clearAll();
    await _weightRepository.clearAll();
    await _savedFoodRepository.clearAllLocal();
    await _mealTemplateRepository.clearAll();
    await _workoutStore.clearAll();
  }
}
