import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/app.dart';
import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final nutritionEngine = NutritionEngine();
  final referenceDate = DateTime(2026, 7, 21);

  OpenFoodFactsService createOpenFoodFactsService() {
    return OpenFoodFactsService(userAgent: OpenFoodFactsConfig.userAgent);
  }

  testWidgets('LoginScreen is shown when unauthenticated', (
    WidgetTester tester,
  ) async {
    final openFoodFactsService = createOpenFoodFactsService();
    final healthRepository = MockHealthRepository(isAvailable: false);
    final authRepository = MockAuthenticationRepository();
    await tester.pumpWidget(
      AygApp(
        controller: AppController(healthRepository: healthRepository),
        openFoodFactsService: openFoodFactsService,
        healthRepository: healthRepository,
        authenticationRepository: authRepository,
      ),
    );

    expect(find.text('Googleでログイン'), findsOneWidget);
    expect(find.text('Appleでログイン'), findsOneWidget);
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('Google login success navigates away from LoginScreen', (
    WidgetTester tester,
  ) async {
    final openFoodFactsService = createOpenFoodFactsService();
    final healthRepository = MockHealthRepository(isAvailable: false);
    final authRepository = MockAuthenticationRepository();
    final dataSyncRepository = MockDataSyncRepository();
    final controller = AppController(
      healthRepository: healthRepository,
      authenticationRepository: authRepository,
      dataSyncRepository: dataSyncRepository,
    );

    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        healthRepository: healthRepository,
        authenticationRepository: authRepository,
      ),
    );

    await tester.tap(find.text('Googleでログイン'));
    await tester.pumpAndSettle();

    expect(find.text('Googleでログイン'), findsNothing);
    expect(authRepository.isAuthenticated, isTrue);
    expect(dataSyncRepository.ensureUserProfileCalled, isTrue);

    await authRepository.dispose();
  });

  testWidgets('Google login cancel does not show failure snackbar', (
    WidgetTester tester,
  ) async {
    final openFoodFactsService = createOpenFoodFactsService();
    final healthRepository = MockHealthRepository(isAvailable: false);
    final authRepository = MockAuthenticationRepository()
      ..simulateGoogleSignInCancelled = true;
    final controller = AppController(
      healthRepository: healthRepository,
      authenticationRepository: authRepository,
    );

    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        healthRepository: healthRepository,
        authenticationRepository: authRepository,
      ),
    );

    await tester.tap(find.text('Googleでログイン'));
    await tester.pumpAndSettle();

    expect(find.text('Googleでログイン'), findsOneWidget);
    expect(find.textContaining('Googleログインに失敗しました'), findsNothing);

    await authRepository.dispose();
  });

  testWidgets('Google login failure shows snackbar', (
    WidgetTester tester,
  ) async {
    final openFoodFactsService = createOpenFoodFactsService();
    final healthRepository = MockHealthRepository(isAvailable: false);
    final authRepository = MockAuthenticationRepository()
      ..simulateGoogleSignInFailure = true;
    final controller = AppController(
      healthRepository: healthRepository,
      authenticationRepository: authRepository,
    );

    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        healthRepository: healthRepository,
        authenticationRepository: authRepository,
      ),
    );

    await tester.tap(find.text('Googleでログイン'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Googleログインに失敗しました'), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('logout returns to LoginScreen', (WidgetTester tester) async {
    final openFoodFactsService = createOpenFoodFactsService();
    final healthRepository = MockHealthRepository(isAvailable: false);
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = AppController(
      healthRepository: healthRepository,
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
        targetDate: referenceDate.add(const Duration(days: 90)),
      ),
    );
    await controller.completeOnboarding();

    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        healthRepository: healthRepository,
        authenticationRepository: authRepository,
      ),
    );

    expect(find.text(AppStrings.navHome), findsWidgets);

    await controller.logout();
    await tester.pumpAndSettle();

    expect(find.text('Googleでログイン'), findsOneWidget);
    expect(find.text(AppStrings.navHome), findsNothing);

    await authRepository.dispose();
  });

  testWidgets('MainShell is shown when authenticated and onboarded', (
    WidgetTester tester,
  ) async {
    final openFoodFactsService = createOpenFoodFactsService();
    final healthRepository = MockHealthRepository(isAvailable: false);
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = AppController(
      healthRepository: healthRepository,
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
        targetDate: referenceDate.add(const Duration(days: 90)),
      ),
    );
    await controller.completeOnboarding();

    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        healthRepository: healthRepository,
        authenticationRepository: authRepository,
      ),
    );

    expect(find.text(AppStrings.navHome), findsWidgets);

    await authRepository.dispose();
  });

  testWidgets('HomeScreen shows remaining kcal from NutritionEngine', (
    WidgetTester tester,
  ) async {
    final openFoodFactsService = createOpenFoodFactsService();
    final healthRepository = MockHealthRepository(isAvailable: false);
    final controller = AppController(
      nutritionEngine: nutritionEngine,
      healthRepository: healthRepository,
    );
    final profile = UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 175,
      weightKg: 75,
    );
    final goal = Goal(
      type: GoalType.maintain,
      targetWeightKg: 75,
      targetDate: referenceDate.add(const Duration(days: 90)),
    );

    controller.setProfile(profile);
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.setGoal(goal);
    controller.addFood(
      FoodEntry(
        id: 'food-1',
        name: 'テスト食品',
        kcalPerUnit: 500,
        proteinPerUnit: 10,
        fatPerUnit: 5,
        carbPerUnit: 40,
        quantity: 1,
        loggedAt: referenceDate,
      ),
    );

    final summary = nutritionEngine.calculateDailySummary(
      profile: profile,
      goal: goal,
      settings: const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
      foodEntries: controller.foodEntries,
      exerciseEntries: controller.exerciseEntries,
      referenceDate: referenceDate,
    );
    final expectedRemainingLabel =
        '${summary.remainingKcal.toStringAsFixed(0)} kcal';

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
        ),
      ),
    );

    expect(find.text(expectedRemainingLabel), findsOneWidget);
  });

  testWidgets('HomeScreen shows -- for food entries with null nutrients', (
    WidgetTester tester,
  ) async {
    final openFoodFactsService = createOpenFoodFactsService();
    final healthRepository = MockHealthRepository(isAvailable: false);
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final controller = AppController(
      nutritionEngine: nutritionEngine,
      healthRepository: healthRepository,
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
        targetDate: referenceDate.add(const Duration(days: 90)),
      ),
    );
    controller.addFood(
      FoodEntry(
        id: 'food-null',
        name: '名前のみ食品',
        quantity: 1,
        loggedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
        ),
      ),
    );

    expect(find.textContaining('-- kcal'), findsOneWidget);
    expect(find.textContaining('P -- g'), findsOneWidget);
  });
}
