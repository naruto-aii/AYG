import 'package:isar/isar.dart';

import '../database/schemas.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/food_repository.dart';
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
  }) : _isar = isar,
       _userRepository = userRepository,
       _settingsRepository = settingsRepository,
       _foodRepository = foodRepository,
       _exerciseRepository = exerciseRepository,
       _weightRepository = weightRepository;

  final Isar _isar;
  final UserRepository _userRepository;
  final SettingsRepository _settingsRepository;
  final FoodRepository _foodRepository;
  final ExerciseRepository _exerciseRepository;
  final WeightRepository _weightRepository;

  Future<void> clearAll() async {
    await _userRepository.clearAll();
    await _settingsRepository.clearAll();
    await _foodRepository.clearAll();
    await _exerciseRepository.clearAll();
    await _weightRepository.clearAll();

    await _isar.writeTxn(() async {
      await _isar.healthWorkoutEntitys.clear();
    });
  }
}
