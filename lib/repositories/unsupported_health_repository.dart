import 'package:isar/isar.dart';

import '../models/health_profile_data.dart';
import 'health_repository.dart';
import 'health_workout_local_store.dart';
import 'weight_repository.dart';

/// Chrome 等 Health 非対応環境。
class UnsupportedHealthRepository implements HealthRepository {
  UnsupportedHealthRepository({
    required WeightRepository weightRepository,
    required Isar isar,
  }) : _weightRepository = weightRepository,
       _workoutStore = HealthWorkoutLocalStore(isar);

  final WeightRepository _weightRepository;
  final HealthWorkoutLocalStore _workoutStore;

  @override
  bool get isAvailable => false;

  @override
  Future<HealthProfileData> fetchProfileData() async {
    return HealthProfileData.empty;
  }

  @override
  Future<List<HealthWorkoutRecord>> loadWorkoutRecords() {
    return _workoutStore.loadWorkoutRecords();
  }

  @override
  Future<List<WeightRecord>> loadWeightRecords() {
    return _weightRepository.loadWeightRecords();
  }

  @override
  Future<bool> requestPermissions() async {
    return false;
  }

  @override
  Future<void> saveWeightRecord(WeightRecord record) {
    return _weightRepository.saveWeightRecord(record);
  }

  @override
  Future<void> saveWorkoutRecords(List<HealthWorkoutRecord> records) {
    return _workoutStore.saveWorkoutRecords(records);
  }
}
