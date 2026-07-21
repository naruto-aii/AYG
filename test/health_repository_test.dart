import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/health_repository_support.dart';
import 'package:ayg/state/app_controller.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MockHealthRepository available', () {
    late MockHealthRepository repository;

    setUp(() {
      repository = MockHealthRepository(
        isAvailable: true,
        permissionsGranted: true,
        profileData: sampleHealthProfileData(),
      );
    });

    test('requests permissions and fetches profile data', () async {
      final granted = await repository.requestPermissions();
      final profile = await repository.fetchProfileData();

      expect(granted, isTrue);
      expect(repository.requestPermissionsCalled, isTrue);
      expect(repository.fetchProfileDataCalled, isTrue);
      expect(profile.birthDate, DateTime(1990, 3, 10));
      expect(profile.gender, Gender.female);
      expect(profile.heightCm, 165);
      expect(profile.weightKg, 58);
      expect(profile.activeEnergyBurnedKcal, 420);
      expect(profile.workouts, hasLength(1));
    });

    test('persists fetched weight and workouts locally', () async {
      final profile = sampleHealthProfileData();
      await HealthRepositorySupport.persistFetchedProfile(repository, profile);

      expect(repository.savedWeights, hasLength(1));
      expect(repository.savedWeights.first.source, WeightSource.health);
      expect(repository.savedWorkouts, hasLength(1));
    });

    test('prefers health weight over manual weight when sync is on', () async {
      final weight = await HealthRepositorySupport.resolvePreferredWeight(
        repository,
        manualWeightKg: 70,
        healthWeightKg: 58,
        useHealthIntegration: true,
      );

      expect(weight, 58);
    });

    test('AppController applies health data and stores workouts', () async {
      final controller = AppController(healthRepository: repository);

      await controller.applyHealthProfileData(sampleHealthProfileData());

      expect(controller.healthPrefill.weightKg, 58);
      expect(controller.healthSnapshot.activeEnergyBurnedKcal, 420);
      expect(repository.savedWeights, isNotEmpty);
      expect(repository.savedWorkouts, isNotEmpty);
    });
  });

  group('MockHealthRepository unavailable', () {
    test('returns empty profile when permissions denied', () async {
      final repository = MockHealthRepository(
        isAvailable: false,
        permissionsGranted: false,
      );

      final granted = await repository.requestPermissions();
      final profile = await repository.fetchProfileData();

      expect(granted, isFalse);
      expect(repository.isAvailable, isFalse);
      expect(profile, HealthProfileData.empty);
    });

    test(
      'UnsupportedHealthRepository is not available on web-like env',
      () async {
        final harness = await setUpIsarHarness();
        final repository = harness.healthRepository;

        expect(repository.isAvailable, isFalse);
        expect(await repository.requestPermissions(), isFalse);
        expect(await repository.fetchProfileData(), HealthProfileData.empty);
      },
    );

    test('manual weight is used when health sync is off', () async {
      final repository = MockHealthRepository(isAvailable: false);
      await repository.saveWeightRecord(
        WeightRecord(
          weightKg: 72,
          recordedAt: DateTime(2026, 7, 21),
          source: WeightSource.manual,
        ),
      );

      final weight = await HealthRepositorySupport.resolvePreferredWeight(
        repository,
        manualWeightKg: 72,
        healthWeightKg: 58,
        useHealthIntegration: false,
      );

      expect(weight, 72);
    });
  });
}
