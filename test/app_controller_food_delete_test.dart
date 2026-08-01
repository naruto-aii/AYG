import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  group('AppController.deleteFood remote persistence', () {
    late IsarTestHarness harness;
    late AppController controller;
    late MockDataSyncRepository dataSyncRepository;

    setUp(() async {
      harness = await IsarTestHarness.create();
      dataSyncRepository = MockDataSyncRepository();
      controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: MockAuthenticationRepository(
          currentUser: const AuthUser(
            id: 'test-user-id',
            email: 'test@example.com',
          ),
        ),
        dataSyncRepository: dataSyncRepository,
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        weightRepository: harness.weightRepository,
        savedFoodRepository: harness.savedFoodRepository,
      );
      controller.profile = UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 170,
        weightKg: 70,
      );
      controller.goal = Goal(
        type: GoalType.maintain,
        targetWeightKg: 70,
        targetDate: DateTime(2026, 12, 31),
      );
      controller.nutritionSettings = const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      );
    });

    tearDown(() async {
      controller.dispose();
      await harness.dispose();
    });

    FoodEntry sampleEntry({String id = 'entry-1'}) {
      return FoodEntry(
        id: id,
        name: 'Rice',
        kcalPerUnit: 200,
        quantity: 1,
        loggedAt: DateTime(2026, 7, 20, 12),
      );
    }

    test('calls Supabase delete before removing local entry', () async {
      await controller.addFood(sampleEntry());
      expect(controller.foodEntries, hasLength(1));

      await controller.deleteFood('entry-1');

      expect(dataSyncRepository.deletedFoodEntryIds, ['entry-1']);
      expect(dataSyncRepository.lastUserId, 'test-user-id');
      expect(controller.foodEntries, isEmpty);
      expect(dataSyncRepository.pushLocalToRemoteCalled, isFalse);
    });

    test('keeps local entry when remote delete fails', () async {
      dataSyncRepository.failDeleteFoodEntry = true;
      await controller.addFood(sampleEntry());

      await expectLater(
        controller.deleteFood('entry-1'),
        throwsA(isA<StateError>()),
      );

      expect(controller.foodEntries, hasLength(1));
      final reloaded = await harness.foodRepository.loadAll();
      expect(reloaded, hasLength(1));
    });

    test('deleted entry does not return after simulated remote pull', () async {
      await controller.addFood(sampleEntry());
      await controller.deleteFood('entry-1');

      await harness.foodRepository.saveAll(const []);
      await controller.loadPersistedState();

      expect(controller.foodEntries, isEmpty);
    });
  });
}
