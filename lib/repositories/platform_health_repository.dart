import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:isar/isar.dart';

import '../models/health_profile_data.dart';
import '../models/user_profile.dart';
import 'health_repository.dart';
import 'health_workout_local_store.dart';
import 'weight_repository.dart';

/// iOS HealthKit / Android Health Connect 連携 Repository。
///
/// Purpose: "Nutrition calculation and fitness tracking."
class PlatformHealthRepository implements HealthRepository {
  PlatformHealthRepository({
    Health? health,
    required WeightRepository weightRepository,
    required Isar isar,
  }) : _health = health ?? Health(),
       _weightRepository = weightRepository,
       _workoutStore = HealthWorkoutLocalStore(isar);

  final Health _health;
  final WeightRepository _weightRepository;
  final HealthWorkoutLocalStore _workoutStore;

  static const _readTypes = [
    HealthDataType.BIRTH_DATE,
    HealthDataType.GENDER,
    HealthDataType.HEIGHT,
    HealthDataType.WEIGHT,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.WORKOUT,
  ];

  @override
  bool get isAvailable => !kIsWeb;

  @override
  Future<bool> requestPermissions() async {
    if (!isAvailable) {
      return false;
    }

    try {
      return await _health.requestAuthorization(_readTypes);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<HealthProfileData> fetchProfileData() async {
    if (!isAvailable) {
      return HealthProfileData.empty;
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    try {
      final birthDate = await _fetchBirthDate();
      final gender = await _fetchGender();
      final heightCm = await _fetchHeightCm();
      final weightKg = await _fetchLatestWeightKg(startOfDay, now);
      final activeEnergyBurnedKcal = await _fetchActiveEnergyBurnedKcal(
        startOfDay,
        now,
      );
      final workouts = await _fetchWorkouts(startOfDay, now);

      return HealthProfileData(
        birthDate: birthDate,
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        activeEnergyBurnedKcal: activeEnergyBurnedKcal,
        workouts: workouts,
      );
    } catch (_) {
      return HealthProfileData.empty;
    }
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
  Future<void> saveWeightRecord(WeightRecord record) {
    return _weightRepository.saveWeightRecord(record);
  }

  @override
  Future<void> saveWorkoutRecords(List<HealthWorkoutRecord> records) {
    return _workoutStore.saveWorkoutRecords(records);
  }

  Future<DateTime?> _fetchBirthDate() async {
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.BIRTH_DATE],
      startTime: DateTime(1900),
      endTime: DateTime.now(),
    );
    if (points.isEmpty) {
      return null;
    }

    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    return points.first.dateFrom;
  }

  Future<Gender?> _fetchGender() async {
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.GENDER],
      startTime: DateTime(1900),
      endTime: DateTime.now(),
    );
    if (points.isEmpty) {
      return null;
    }

    final raw = points.first.value.toString().toLowerCase();
    if (raw.contains('female')) {
      return Gender.female;
    }
    if (raw.contains('male')) {
      return Gender.male;
    }

    return Gender.other;
  }

  Future<double?> _fetchHeightCm() async {
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.HEIGHT],
      startTime: DateTime(1900),
      endTime: DateTime.now(),
    );
    if (points.isEmpty) {
      return null;
    }

    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final value = points.first.value;
    if (value is! NumericHealthValue) {
      return null;
    }

    final numeric = value.numericValue.toDouble();
    return numeric > 3 ? numeric : numeric * 100;
  }

  Future<double?> _fetchLatestWeightKg(DateTime start, DateTime end) async {
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WEIGHT],
      startTime: start.subtract(const Duration(days: 30)),
      endTime: end,
    );
    if (points.isEmpty) {
      return null;
    }

    points.sort((a, b) => b.dateTo.compareTo(a.dateTo));
    final value = points.first.value;
    if (value is! NumericHealthValue) {
      return null;
    }

    return value.numericValue.toDouble();
  }

  Future<double> _fetchActiveEnergyBurnedKcal(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      startTime: start,
      endTime: end,
    );

    var total = 0.0;
    for (final point in points) {
      final value = point.value;
      if (value is NumericHealthValue) {
        total += value.numericValue.toDouble();
      }
    }

    return total;
  }

  Future<List<HealthWorkoutRecord>> _fetchWorkouts(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: start,
      endTime: end,
    );

    return points.map((point) {
      final value = point.value;
      final workoutValue = value is WorkoutHealthValue ? value : null;
      final calories = workoutValue?.totalEnergyBurned?.toDouble();

      return HealthWorkoutRecord(
        id: '${point.dateFrom.millisecondsSinceEpoch}_${point.dateTo.millisecondsSinceEpoch}',
        activityType: workoutValue?.workoutActivityType.name ?? 'workout',
        startTime: point.dateFrom,
        endTime: point.dateTo,
        caloriesBurned: calories,
      );
    }).toList();
  }
}
