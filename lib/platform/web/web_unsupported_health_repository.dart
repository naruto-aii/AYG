import '../../../models/health_profile_data.dart';
import '../../../repositories/health_repository.dart';
import '../../../repositories/contracts/weight_repository_base.dart';
import 'web_health_workout_store.dart';

/// Web プレビュー向け Health 非対応 Repository。
class WebUnsupportedHealthRepository implements HealthRepository {
  WebUnsupportedHealthRepository({
    required WeightRepositoryBase weightRepository,
    WebHealthWorkoutStore? workoutStore,
  }) : _weightRepository = weightRepository,
       _workoutStore = workoutStore ?? WebHealthWorkoutStore();

  final WeightRepositoryBase _weightRepository;
  final WebHealthWorkoutStore _workoutStore;

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
