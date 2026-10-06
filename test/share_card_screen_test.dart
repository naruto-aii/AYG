import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/screens/weight/weight_tab_screen.dart';
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

  testWidgets('home share stays quiet until the icon is tapped', (
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
          shareCard: (content, _) async {
            sent = content;
            return ShareResult.sent;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('記録を共有'), findsOneWidget);
    expect(find.text('この内容で送る'), findsNothing);
    expect(find.text('カロナビ+で共有'), findsNothing);

    await tester.tap(find.byTooltip('記録を共有'));
    await tester.pumpAndSettle();

    expect(find.text('今日のまとめ'), findsOneWidget);
    expect(find.text('連続記録'), findsOneWidget);
    expect(find.text('目標まであと'), findsNothing);
    expect(find.textContaining('目標まであと'), findsWidgets);

    await tester.tap(find.text('この内容で送る'));
    await tester.pumpAndSettle();

    expect(sent, isNotNull);
    expect(sent!.kind, ShareCardKind.meal);
    expect(sent!.message, contains('500 kcal'));
    expect(sent!.message, contains(shareDownloadUrl));
    expect(sent!.message, isNot(contains('kg')));
    expect(find.text('この内容で送る'), findsNothing);
  });

  testWidgets('weight share can hide the change before sending', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController();
    final now = DateTime.now();
    controller.weightEntries.addAll([
      WeightEntry(
        id: 'start',
        weightKg: 90,
        recordedAt: now.subtract(const Duration(days: 20)),
        source: WeightSource.manual,
      ),
      WeightEntry(
        id: 'middle',
        weightKg: 80,
        recordedAt: now.subtract(const Duration(days: 10)),
        source: WeightSource.manual,
      ),
      WeightEntry(
        id: 'newer',
        weightKg: 78.4,
        recordedAt: now.subtract(const Duration(days: 1)),
        source: WeightSource.manual,
      ),
    ]);
    ShareCardContent? sent;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WeightTabScreen(
          controller: controller,
          shareCard: (content, _) async {
            sent = content;
            return ShareResult.sent;
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('変化を共有'), findsOneWidget);
    expect(find.text('この内容で送る'), findsNothing);

    await tester.tap(find.byTooltip('変化を共有'));
    await tester.pumpAndSettle();
    expect(find.text('数字はぼかしています'), findsOneWidget);
    expect(find.text('非公開'), findsNothing);

    await tester.tap(find.text('隠す'));
    await tester.pumpAndSettle();
    expect(find.text('非公開'), findsOneWidget);
    expect(find.text('11.6'), findsNothing);

    await tester.ensureVisible(find.text('この内容で送る'));
    await tester.tap(find.text('この内容で送る'));
    await tester.pumpAndSettle();

    expect(sent!.kind, ShareCardKind.weight);
    expect(sent!.privacy, WeightPrivacy.hidden);
    expect(sent!.message, contains(shareDownloadUrl));
    expect(RegExp(r'\d').hasMatch(sent!.message), isFalse);
    expect(sent!.message, isNot(contains('80')));
    expect(sent!.message, isNot(contains('78.4')));
  });
}
