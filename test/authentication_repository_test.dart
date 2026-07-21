import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/auth_exceptions.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/local_session_store.dart';
import 'package:ayg/repositories/supabase_authentication_repository.dart';
import 'package:ayg/services/local_user_data_clearer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';

void main() {
  group('MockAuthenticationRepository', () {
    late MockAuthenticationRepository authRepository;

    setUp(() {
      authRepository = MockAuthenticationRepository();
    });

    tearDown(() async {
      await authRepository.dispose();
    });

    test('starts unauthenticated', () {
      expect(authRepository.isAuthenticated, isFalse);
    });

    test('loginWithGoogle sets current user', () async {
      await authRepository.loginWithGoogle();

      expect(authRepository.loginWithGoogleCalled, isTrue);
      expect(authRepository.currentUser?.id, 'test-user-id');
      expect(authRepository.isAuthenticated, isTrue);
    });

    test('loginWithGoogle cancel throws GoogleSignInCancelledException', () {
      authRepository.simulateGoogleSignInCancelled = true;

      expect(
        authRepository.loginWithGoogle(),
        throwsA(isA<GoogleSignInCancelledException>()),
      );
    });

    test('loginWithGoogle failure throws GoogleSignInFailedException', () {
      authRepository.simulateGoogleSignInFailure = true;

      expect(
        authRepository.loginWithGoogle(),
        throwsA(isA<GoogleSignInFailedException>()),
      );
    });

    test('logout clears current user', () async {
      await authRepository.loginWithGoogle();
      await authRepository.logout();

      expect(authRepository.logoutCalled, isTrue);
      expect(authRepository.isAuthenticated, isFalse);
    });

    test('loginWithApple is not implemented', () {
      expect(
        authRepository.loginWithApple(),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  group('UnconfiguredAuthenticationRepository', () {
    test('is always unauthenticated', () {
      final repository = UnconfiguredAuthenticationRepository();

      expect(repository.isAuthenticated, isFalse);
      expect(repository.currentUser, isNull);
    });
  });

  group('AppController auth flow', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('handleAuthenticatedSession syncs and loads state', () async {
      final authRepository = MockAuthenticationRepository();
      final dataSyncRepository = MockDataSyncRepository();
      final controller = AppController(
        authenticationRepository: authRepository,
        dataSyncRepository: dataSyncRepository,
        localSessionStore: LocalSessionStore(),
      );

      await authRepository.loginWithGoogle();
      await controller.handleAuthenticatedSession();

      expect(dataSyncRepository.ensureUserProfileCalled, isTrue);
      expect(dataSyncRepository.pullRemoteToLocalCalled, isTrue);
      expect(dataSyncRepository.lastUserId, 'test-user-id');

      await authRepository.dispose();
    });

    test('initialize restores session and pulls remote data', () async {
      SharedPreferences.setMockInitialValues({
        'last_authenticated_user_id': 'user-1',
      });
      final authRepository = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      final dataSyncRepository = MockDataSyncRepository();
      final controller = AppController(
        authenticationRepository: authRepository,
        dataSyncRepository: dataSyncRepository,
        localSessionStore: LocalSessionStore(),
      );

      await controller.initialize();

      expect(authRepository.restoreSessionCalled, isTrue);
      expect(dataSyncRepository.ensureUserProfileCalled, isTrue);
      expect(dataSyncRepository.pullRemoteToLocalCalled, isTrue);

      await authRepository.dispose();
    });

    test('empty initial pull does not throw', () async {
      final authRepository = MockAuthenticationRepository();
      final dataSyncRepository = MockDataSyncRepository();
      final controller = AppController(
        authenticationRepository: authRepository,
        dataSyncRepository: dataSyncRepository,
        localSessionStore: LocalSessionStore(),
      );

      await authRepository.loginWithGoogle();
      await controller.handleAuthenticatedSession();

      expect(controller.profile, isNull);
      expect(controller.onboardingComplete, isFalse);

      await authRepository.dispose();
    });

    test('logout clears authenticated and in-memory state', () async {
      final authRepository = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      final controller = AppController(
        authenticationRepository: authRepository,
      );

      controller.setProfile(
        UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 175,
          weightKg: 75,
        ),
      );

      await controller.logout();

      expect(authRepository.logoutCalled, isTrue);
      expect(controller.isAuthenticated, isFalse);
      expect(controller.profile, isNull);

      await authRepository.dispose();
    });

    test('user switch clears local Isar data before pull', () async {
      SharedPreferences.setMockInitialValues({
        'last_authenticated_user_id': 'user-a',
      });
      final harness = await IsarTestHarness.create();
      addTearDown(harness.dispose);

      await harness.userRepository.saveProfile(
        UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 175,
          weightKg: 75,
        ),
      );
      await harness.foodRepository.save(
        FoodEntry(
          id: 'food-1',
          name: 'Previous user food',
          quantity: 1,
          loggedAt: DateTime.now(),
        ),
      );

      final authRepository = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-b', email: 'b@example.com'),
      );
      final dataSyncRepository = MockDataSyncRepository();
      final localUserDataClearer = LocalUserDataClearer(
        isar: harness.isar,
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        weightRepository: harness.weightRepository,
      );
      final controller = AppController(
        authenticationRepository: authRepository,
        dataSyncRepository: dataSyncRepository,
        localSessionStore: LocalSessionStore(),
        localUserDataClearer: localUserDataClearer,
        userRepository: harness.userRepository,
        settingsRepository: harness.settingsRepository,
        foodRepository: harness.foodRepository,
        exerciseRepository: harness.exerciseRepository,
        weightRepository: harness.weightRepository,
      );

      await controller.handleAuthenticatedSession();

      expect(dataSyncRepository.pullRemoteToLocalCalled, isTrue);
      expect(dataSyncRepository.lastUserId, 'user-b');
      expect(await harness.userRepository.loadProfile(), isNull);
      expect(await harness.foodRepository.loadAll(), isEmpty);
      expect(controller.profile, isNull);

      await authRepository.dispose();
    });

    test('onboarding completion triggers remote push', () async {
      final authRepository = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      final dataSyncRepository = MockDataSyncRepository();
      final controller = AppController(
        authenticationRepository: authRepository,
        dataSyncRepository: dataSyncRepository,
        localSessionStore: LocalSessionStore(),
      );

      controller.setProfile(
        UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 175,
          weightKg: 75,
        ),
      );
      controller.setNutritionSettings(
        const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
      );
      controller.setGoal(
        Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: DateTime(2026, 12, 31),
        ),
      );

      await controller.completeOnboarding();
      await Future<void>.delayed(Duration.zero);

      expect(dataSyncRepository.pushLocalToRemoteCalled, isTrue);
      expect(dataSyncRepository.lastUserId, 'user-1');

      await authRepository.dispose();
    });
  });
}
