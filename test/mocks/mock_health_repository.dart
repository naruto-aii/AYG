import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/health_repository.dart';

class MockHealthRepository implements HealthRepository {
  MockHealthRepository({
    this.isAvailable = true,
    this.permissionsGranted = true,
    this.profileData = HealthProfileData.empty,
  });

  @override
  final bool isAvailable;

  bool permissionsGranted;
  HealthProfileData profileData;

  final List<WeightRecord> savedWeights = [];
  final List<HealthWorkoutRecord> savedWorkouts = [];

  bool requestPermissionsCalled = false;
  bool fetchProfileDataCalled = false;

  @override
  Future<HealthProfileData> fetchProfileData() async {
    fetchProfileDataCalled = true;
    return profileData;
  }

  @override
  Future<List<HealthWorkoutRecord>> loadWorkoutRecords() async {
    return List.unmodifiable(savedWorkouts);
  }

  @override
  Future<List<WeightRecord>> loadWeightRecords() async {
    return List.unmodifiable(savedWeights);
  }

  @override
  Future<bool> requestPermissions() async {
    requestPermissionsCalled = true;
    return permissionsGranted;
  }

  @override
  Future<void> saveWeightRecord(WeightRecord record) async {
    savedWeights.add(record);
  }

  @override
  Future<void> saveWorkoutRecords(List<HealthWorkoutRecord> records) async {
    savedWorkouts.addAll(records);
  }
}

HealthProfileData sampleHealthProfileData() {
  return HealthProfileData(
    birthDate: DateTime(1990, 3, 10),
    gender: Gender.female,
    heightCm: 165,
    weightKg: 58,
    activeEnergyBurnedKcal: 420,
    workouts: [
      HealthWorkoutRecord(
        id: 'workout-1',
        activityType: 'running',
        startTime: DateTime(2026, 7, 21, 7),
        endTime: DateTime(2026, 7, 21, 7, 30),
        caloriesBurned: 180,
      ),
    ],
  );
}
