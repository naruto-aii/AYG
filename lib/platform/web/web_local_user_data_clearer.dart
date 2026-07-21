import '../../../repositories/contracts/exercise_repository_base.dart';
import '../../../repositories/contracts/food_repository_base.dart';
import '../../../repositories/contracts/settings_repository_base.dart';
import '../../../repositories/contracts/user_repository_base.dart';
import '../../../repositories/contracts/weight_repository_base.dart';
import '../../../services/local_user_data_clearer_base.dart';
import 'web_health_workout_store.dart';

/// Web 向けローカルデータ消去（Isar 不使用）。
class WebLocalUserDataClearer implements LocalUserDataClearerBase {
  WebLocalUserDataClearer({
    required UserRepositoryBase userRepository,
    required SettingsRepositoryBase settingsRepository,
    required FoodRepositoryBase foodRepository,
    required ExerciseRepositoryBase exerciseRepository,
    required WeightRepositoryBase weightRepository,
    WebHealthWorkoutStore? workoutStore,
  }) : _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _weightRepository = weightRepository,
       _workoutStore = workoutStore ?? WebHealthWorkoutStore();

  final UserRepositoryBase _userRepository;
  final SettingsRepositoryBase _settingsRepository;
  final FoodRepositoryBase _foodRepository;
  final ExerciseRepositoryBase _exerciseRepository;
  final WeightRepositoryBase _weightRepository;
  final WebHealthWorkoutStore _workoutStore;

  @override
  Future<void> clearAll() async {
    await _userRepository.clearAll();
    await _settingsRepository.clearAll();
    await _foodRepository.clearAll();
    await _exerciseRepository.clearAll();
    await _weightRepository.clearAll();
    await _workoutStore.clearAll();
  }
}
