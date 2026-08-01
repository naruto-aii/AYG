import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_source_type.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/public_food_search_match.dart';
import 'package:ayg/models/saved_food.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/services/public_food_meal_add_flow.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/saved_food/public_food_detail_sheet.dart';
import 'package:ayg/widgets/saved_food/saved_food_meal_quantity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 7, 20);

  SavedFood publicFood({
    String? servingUnitLabel = 'g',
    double baseAmount = 100,
  }) {
    return SavedFood(
      foodId: 'public-food-1',
      ownerUserId: 'other-user',
      name: '公開オートミール',
      normalizedName: '公開オートミール',
      baseAmount: baseAmount,
      unitType: FoodUnitType.g,
      servingUnitLabel: servingUnitLabel,
      kcalPerBase: 380,
      proteinPerBase: 13,
      fatPerBase: 7,
      carbPerBase: 69,
      sourceType: FoodSourceType.manual,
      createdAt: now,
      updatedAt: now,
    );
  }

  PublicFoodSearchMatch matchFor(SavedFood food) {
    return PublicFoodSearchMatch(
      food: food,
      goodCount: 1,
      badCount: 0,
      matchType: PublicFoodSearchMatchType.exactName,
    );
  }

  group('PublicFoodMealAddFlow', () {
    late IsarTestHarness harness;
    late AppController controller;

    setUp(() async {
      harness = await IsarTestHarness.create();
      controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: MockAuthenticationRepository(
          currentUser: const AuthUser(
            id: 'test-user-id',
            email: 'test@example.com',
          ),
        ),
        dataSyncRepository: MockDataSyncRepository(),
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

    Future<void> pumpHost(
      WidgetTester tester, {
      required Widget child,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: child),
        ),
      );
      await tester.pump();
    }

    Future<void> pumpFrames(WidgetTester tester, {int frames = 10}) async {
      for (var i = 0; i < frames; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('opens quantity sheet when baseServingDefined is true', (
      tester,
    ) async {
      await pumpHost(
        tester,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => PublicFoodMealAddFlow.start(
                context: context,
                controller: controller,
                food: publicFood(),
              ),
              child: const Text('start'),
            );
          },
        ),
      );

      await tester.tap(find.text('start'));
      await pumpFrames(tester);

      expect(find.text('公開オートミール'), findsOneWidget);
      expect(find.text('食べた量'), findsOneWidget);
      expect(find.text('g'), findsWidgets);
      expect(find.text('この内容で追加'), findsOneWidget);
    });

    testWidgets('shows blocked dialog when serving is undefined', (
      tester,
    ) async {
      await pumpHost(
        tester,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => PublicFoodMealAddFlow.start(
                context: context,
                controller: controller,
                food: publicFood(servingUnitLabel: null),
              ),
              child: const Text('start'),
            );
          },
        ),
      );

      await tester.tap(find.text('start'));
      await pumpFrames(tester);

      expect(find.text('直接追加できません'), findsOneWidget);
      expect(
        find.text('この食品には基準量が設定されていないため、直接追加できません。'),
        findsOneWidget,
      );
      expect(find.text('キャンセル'), findsOneWidget);
    });

    testWidgets('detail sheet closes before opening quantity sheet', (tester) async {
      SavedFood? mealFood;
      await pumpHost(
        tester,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                mealFood = await showPublicFoodDetailSheet(
                  context: context,
                  controller: controller,
                  match: matchFor(publicFood()),
                  selectForMealEntry: false,
                );
                if (mealFood != null && context.mounted) {
                  await PublicFoodMealAddFlow.start(
                    context: context,
                    controller: controller,
                    food: mealFood!,
                  );
                }
              },
              child: const Text('open detail'),
            );
          },
        ),
      );

      await tester.tap(find.text('open detail'));
      await pumpFrames(tester, frames: 15);

      expect(find.text('食事に追加'), findsOneWidget);

      await tester.tap(find.text('食事に追加'));
      await pumpFrames(tester);

      expect(find.text('食事に追加'), findsNothing);
      expect(find.text('食べた量'), findsOneWidget);
      expect(mealFood, isNotNull);
    });

    testWidgets('detail sheet returns food for blocked serving dialog flow', (
      tester,
    ) async {
      SavedFood? mealFood;
      await pumpHost(
        tester,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                mealFood = await showPublicFoodDetailSheet(
                  context: context,
                  controller: controller,
                  match: matchFor(publicFood(servingUnitLabel: null)),
                  selectForMealEntry: false,
                );
                if (mealFood != null && context.mounted) {
                  await PublicFoodMealAddFlow.start(
                    context: context,
                    controller: controller,
                    food: mealFood!,
                  );
                }
              },
              child: const Text('open detail'),
            );
          },
        ),
      );

      await tester.tap(find.text('open detail'));
      await pumpFrames(tester, frames: 15);
      await tester.tap(find.text('食事に追加'));
      await pumpFrames(tester);

      expect(find.text('直接追加できません'), findsOneWidget);
      expect(mealFood, isNotNull);
    });

    testWidgets('quantity change scales nutrients proportionally', (tester) async {
      await pumpHost(
        tester,
        child: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => showSavedFoodMealQuantitySheet(
                context: context,
                controller: controller,
                food: publicFood(baseAmount: 100),
              ),
              child: const Text('start'),
            );
          },
        ),
      );

      await tester.tap(find.text('start'));
      await pumpFrames(tester, frames: 15);

      await tester.enterText(find.byType(TextFormField), '200');
      await pumpFrames(tester);

      expect(find.textContaining('760'), findsWidgets);
    });

    test('addMealEntryFromSavedFoodMaster creates one entry from public food', () async {
      await controller.addMealEntryFromSavedFoodMaster(
        food: publicFood(),
        consumedQuantity: 100,
        loggedAt: DateTime(2026, 7, 20, 12),
      );

      expect(controller.foodEntries, hasLength(1));
      expect(controller.foodEntries.single.name, '公開オートミール');
      expect(controller.foodEntries.single.kcalPerBase, 380);
      expect(controller.foodEntries.single.consumedAmount, 100);
    });
  });
}
