import 'package:ayg/app.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/macro_nutrition_test_helpers.dart';

/// 実画面Screenshot取得用（iOS Simulator / Emulator / Chrome）。
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture home prototype screenshot with Japanese text', (
    WidgetTester tester,
  ) async {
    final setup = await createOnboardedAppController();
    final now = DateTime.now();

    await setup.controller.addFood(
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
    await setup.controller.addFood(
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
    await setup.controller.addExercise(
      ExerciseEntry(
        id: 'exercise-1',
        name: 'ウォーキング',
        durationMin: 30,
        burnedKcal: 120,
        loggedAt: DateTime(now.year, now.month, now.day, 18, 0),
      ),
    );

    await tester.pumpWidget(
      AygApp(
        controller: setup.controller,
        openFoodFactsService: setup.openFoodFactsService,
        healthRepository: setup.healthRepository,
        authenticationRepository: setup.authRepository,
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.text(AppStrings.navHome), findsWidgets);
    expect(find.text('サラダチキン'), findsOneWidget);
    expect(find.text('玄米おにぎり'), findsOneWidget);
    expect(find.text('ウォーキング'), findsOneWidget);

    // フル画面確認用: 上部Screenshot
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('home_mobile_real_top');

    // 今日の食事・運動一覧までスクロール
    await tester.drag(
      find.byType(SingleChildScrollView),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await binding.takeScreenshot('home_mobile_real_scrolled');
  });
}
