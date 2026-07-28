import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';

import '../test/mocks/mock_health_repository.dart';

/// Mobile幅ホーム画面のプロトタイプScreenshot（golden）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('HomeScreen mobile prototype golden', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final openFoodFactsService = OpenFoodFactsService(
      userAgent: OpenFoodFactsConfig.userAgent,
    );
    final healthRepository = MockHealthRepository(isAvailable: false);
    final controller = AppController(
      nutritionEngine: NutritionEngine(),
      healthRepository: healthRepository,
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: openFoodFactsService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/home_mobile_prototype.png'),
    );
  });
}
