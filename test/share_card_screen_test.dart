import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/share_card_content.dart';
import 'package:ayg/services/share_links.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<AppController> homeController() async {
    final controller = AppController(
      nutritionEngine: NutritionEngine(),
      healthRepository: MockHealthRepository(isAvailable: false),
    );
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
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    controller.setGoal(
      Goal(
        type: GoalType.maintain,
        targetWeightKg: 70,
        targetDate: DateTime.now().add(const Duration(days: 90)),
      ),
    );
    await controller.addFood(
      FoodEntry(
        id: 'food-1',
        name: 'ごはん',
        kcalPerUnit: 500,
        proteinPerUnit: 8,
        fatPerUnit: 1,
        carbPerUnit: 110,
        quantity: 1,
        loggedAt: DateTime.now(),
      ),
    );
    return controller;
  }

  testWidgets('home share opens the sheet without a chooser', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    ShareCardContent? sent;
    final controller = await homeController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
          shareCard: (content) async {
            sent = content;
            return ShareResult.sent;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('記録を共有'), findsOneWidget);
    expect(find.text('この内容で送る'), findsNothing);
    expect(find.text('連続記録'), findsNothing);
    expect(find.text('正方形'), findsNothing);

    await tester.tap(find.byTooltip('記録を共有'));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!.headline, '500');
    expect(sent!.message, contains('500 kcal'));
    expect(sent!.message, contains(AppStrings.loginTagline));
    expect(sent!.message, contains(shareDownloadUrl));
    expect(sent!.message, isNot(contains('運動で')));
    expect(sent!.message, isNot(contains('kg')));
    expect(find.text('この内容で送る'), findsNothing);
    expect(find.text('連続記録'), findsNothing);
  });
}
