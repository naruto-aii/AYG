import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_colors.dart';
import 'package:ayg/theme/app_radius.dart';
import 'package:ayg/theme/app_shadows.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../test/mocks/mock_authentication_repository.dart';
import '../test/mocks/mock_health_repository.dart';

/// プロトタイプScreenshot用（iOS Simulator / Chrome）。
/// 実行: flutter run -t tool/prototype_home_main.dart -d <device>
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final openFoodFactsService = OpenFoodFactsService(
    userAgent: OpenFoodFactsConfig.userAgent,
  );
  final healthRepository = MockHealthRepository(isAvailable: false);
  final authRepository = MockAuthenticationRepository(
    currentUser: const AuthUser(
      id: 'prototype-user',
      email: 'prototype@example.com',
    ),
  );
  final controller = AppController(
    healthRepository: healthRepository,
    authenticationRepository: authRepository,
  );

  controller.setProfile(
    UserProfile(
      birthDate: DateTime(1990, 4, 15),
      gender: Gender.female,
      heightCm: 162,
      weightKg: 58,
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
      type: GoalType.lose,
      targetWeightKg: 55,
      targetDate: DateTime(2026, 10, 1),
    ),
  );
  await controller.completeOnboarding();

  final now = DateTime.now();
  await controller.addFood(
    FoodEntry(
      id: 'food-1',
      name: 'サラダチキン',
      kcalPerUnit: 428,
      proteinPerUnit: 50,
      fatPerUnit: 8,
      carbPerUnit: 2,
      quantity: 1,
      loggedAt: DateTime(now.year, now.month, now.day, 7, 30),
    ),
  );
  await controller.addFood(
    FoodEntry(
      id: 'food-2',
      name: '玄米おにぎり',
      kcalPerUnit: 586,
      proteinPerUnit: 12,
      fatPerUnit: 4,
      carbPerUnit: 120,
      quantity: 1,
      loggedAt: DateTime(now.year, now.month, now.day, 12, 15),
    ),
  );
  await controller.addExercise(
    ExerciseEntry(
      id: 'exercise-1',
      name: 'ウォーキング',
      durationMin: 30,
      burnedKcal: 120,
      loggedAt: DateTime(now.year, now.month, now.day, 18, 0),
    ),
  );

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: _PrototypeHomeShell(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
      ),
    ),
  );
}

class _PrototypeHomeShell extends StatelessWidget {
  const _PrototypeHomeShell({
    required this.controller,
    required this.openFoodFactsService,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: HomeScreen(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: AppRadius.bottomNav,
            boxShadow: AppShadows.subtle,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.bottomNav,
            child: NavigationBar(
              selectedIndex: 0,
              elevation: 0,
              height: 64,
              backgroundColor: AppColors.cardWhite,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: AppStrings.navHome,
                ),
                NavigationDestination(
                  icon: Icon(Icons.restaurant_outlined),
                  selectedIcon: Icon(Icons.restaurant),
                  label: AppStrings.navFood,
                ),
                NavigationDestination(
                  icon: Icon(Icons.fitness_center_outlined),
                  selectedIcon: Icon(Icons.fitness_center),
                  label: AppStrings.navWorkout,
                ),
                NavigationDestination(
                  icon: Icon(Icons.monitor_weight_outlined),
                  selectedIcon: Icon(Icons.monitor_weight),
                  label: AppStrings.navWeight,
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: AppStrings.navSettings,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
