import 'dart:io';

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/calculation/calorie_target_mode.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/screens/history/day_history_screen.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/utils/kcal_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home and history omit an overlapping workout from 消費', (
    tester,
  ) async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final workoutStart = day.add(const Duration(hours: 15));
    final walkAt = day.add(const Duration(hours: 8));
    final controller = AppController(
      nutritionEngine: NutritionEngine(),
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    addTearDown(controller.dispose);
    controller.setProfile(
      UserProfile(
        birthDate: DateTime(1990, 1, 1),
        gender: Gender.male,
        heightCm: 175,
        weightKg: 70,
      ),
    );
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: true,
        activityLevel: ActivityLevel.moderate,
        calorieTargetMode: CalorieTargetMode.manual,
        manualTargetKcal: 2000,
        manualProteinG: 100,
        manualFatG: 60,
        manualCarbG: 250,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 70,
        targetDate: DateTime(2026, 12, 31),
      ),
    );
    controller.setHealthSnapshot(
      const HealthSnapshot(activeEnergyBurnedKcal: 0),
    );
    controller.healthWorkouts = [
      HealthWorkoutRecord(
        id: 'run',
        activityType: 'running',
        startTime: workoutStart,
        endTime: workoutStart.add(const Duration(minutes: 30)),
      ),
    ];
    controller.exerciseEntries.addAll([
      ExerciseEntry(
        id: 'run',
        name: 'ランニング',
        durationMin: 30,
        burnedKcal: 100,
        netKcal: 100,
        loggedAt: workoutStart,
      ),
      ExerciseEntry(
        id: 'walk',
        name: '散歩',
        durationMin: 20,
        burnedKcal: 50.4,
        netKcal: 50.4,
        loggedAt: walkAt,
      ),
    ]);
    controller.refreshDailySummary();

    final shown = controller.displayedSummaryKcal(now);
    expect(shown.exercise, 50);
    expect(shown.burn, 50);
    expect(shown.burn, shown.exercise + shown.health);
    expect(mealWidgetFiguresFromDisplayed(shown).burnKcal, shown.burn);
    expect(
      File('lib/services/daily_coach_session.dart').readAsStringSync(),
      contains('displayedSummaryKcal'),
    );
    expect(
      File('lib/screens/coach/cook_coach_screen.dart').readAsStringSync(),
      contains('displayedSummaryKcal'),
    );

    final facts = OpenFoodFactsService(userAgent: 'test');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(controller: controller, openFoodFactsService: facts),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+50'), findsOneWidget);
    expect(find.text('+100'), findsNothing);
    expect(find.text(overlappedExerciseLabel), findsOneWidget);
    expect(find.text('50'), findsWidgets);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DayHistoryScreen(
          controller: controller,
          openFoodFactsService: facts,
          selectedDay: now,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('+50'), findsNWidgets(2));
    expect(find.text('+100'), findsNothing);
    expect(find.text(overlappedExerciseLabel), findsOneWidget);
  });
}
