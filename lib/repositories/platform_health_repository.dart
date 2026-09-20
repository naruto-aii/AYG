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
  bool _configured = false;

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
  String? lastFailureMessage;

  @override
  Future<bool> requestPermissions() async {
    lastFailureMessage = null;
    if (!isAvailable) {
      lastFailureMessage = 'この端末では Health 連携に対応していません。';
      return false;
    }

    try {
      await _ensureConfigured();
      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: List<HealthDataAccess>.filled(
          _readTypes.length,
          HealthDataAccess.READ,
        ),
      );
      if (!granted) {
        lastFailureMessage =
            'Health の許可が得られませんでした。iPhoneの設定 → プライバシーとセキュリティ → ヘルスケア → カロナビ で読み取りをオンにしてください。';
      }
      return granted;
    } catch (error) {
      lastFailureMessage = _messageForError(error);
      return false;
    }
  }

  @override
  Future<HealthProfileData> fetchProfileData() async {
    if (!isAvailable) {
      lastFailureMessage ??= 'この端末では Health 連携に対応していません。';
      return HealthProfileData.empty;
    }

    try {
      await _ensureConfigured();
    } catch (error) {
      lastFailureMessage = _messageForError(error);
      return HealthProfileData.empty;
    }

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final birthDate = await _safeFetch('生年月日', _fetchBirthDate);
    final gender = await _safeFetch('性別', _fetchGender);
    final heightCm = await _safeFetch('身長', _fetchHeightCm);
    final weightKg = await _safeFetch(
      '体重',
      () => _fetchLatestWeightKg(startOfDay, now),
    );
    final activeEnergyBurnedKcal = await _safeFetch(
      'アクティブエネルギー',
      () => _fetchActiveEnergyBurnedKcal(startOfDay, now),
    );
    final workouts =
        await _safeFetch('ワークアウト', () => _fetchWorkouts(startOfDay, now)) ??
        const <HealthWorkoutRecord>[];

    final data = HealthProfileData(
      birthDate: birthDate,
      gender: gender,
      heightCm: heightCm,
      weightKg: weightKg,
      activeEnergyBurnedKcal: activeEnergyBurnedKcal,
      workouts: workouts,
    );

    if (!data.hasAnyValue && lastFailureMessage == null) {
      lastFailureMessage =
          'Health から値を読めませんでした。ヘルスケアに体重・身長が入っているか、カロナビの読み取り許可を確認してください。';
    } else if (data.hasAnyValue) {
      lastFailureMessage = null;
    }

    return data;
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

  Future<void> _ensureConfigured() async {
    if (_configured) {
      return;
    }
    await _health.configure();
    _configured = true;
  }

  Future<T?> _safeFetch<T>(String label, Future<T?> Function() run) async {
    try {
      return await run();
    } catch (error) {
      lastFailureMessage = '$labelを取得できませんでした。${_messageForError(error)}';
      return null;
    }
  }

  String _messageForError(Object error) {
    final text = error.toString();
    if (text.contains('entitlement') ||
        text.contains('Authorization not determined') ||
        text.contains('Missing')) {
      return 'HealthKit の権限がビルドに入っていません。Xcode の Signing & Capabilities に HealthKit があるか確認し、USB で入れ直してください。';
    }
    return text;
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

  Future<double?> _fetchActiveEnergyBurnedKcal(
    DateTime start,
    DateTime end,
  ) async {
    final points = await _health.getHealthDataFromTypes(
      types: [HealthDataType.ACTIVE_ENERGY_BURNED],
      startTime: start,
      endTime: end,
    );

    var total = 0.0;
    var sawValue = false;
    for (final point in points) {
      final value = point.value;
      if (value is NumericHealthValue) {
        total += value.numericValue.toDouble();
        sawValue = true;
      }
    }

    return sawValue ? total : null;
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
