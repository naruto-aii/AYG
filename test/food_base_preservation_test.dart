import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/repositories/coach_slot_store.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OpenFoodFactsService service() {
    return OpenFoodFactsService(userAgent: 'AYG/test (test@example.com)');
  }

  Future<void> openEditor(
    WidgetTester tester, {
    required AppController controller,
    FoodEntry? entry,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FoodFormScreen(
                        controller: controller,
                        openFoodFactsService: service(),
                        entry: entry,
                      ),
                    ),
                  );
                },
                child: const Text('open form'),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('open form'));
    await tester.pumpAndSettle();
  }

  Future<void> pickAnotherDay(WidgetTester tester) async {
    await tester.ensureVisible(
      find.byKey(const ValueKey('food_logged_at_field')),
    );
    await tester.tap(find.byKey(const ValueKey('food_logged_at_field')));
    await tester.pumpAndSettle();
    final today = DateTime.now().day.toString();
    final other = today == '1' ? '2' : '1';
    await tester.tap(find.text(other).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  FoodEntry compositionEntry() {
    return FoodEntry(
      id: 'curry',
      name: 'チキンカレー',
      kcalPerBase: 131,
      proteinPerBase: 6,
      fatPerBase: 5,
      carbPerBase: 15,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      consumedAmount: 150,
      sourceType: FoodEntrySource.mextSfct,
      officialFoodCode: '11111',
      officialFoodName: 'チキンカレー',
      mealGroupId: 'group-curry',
      mealGroupName: '夕食',
      sortOrder: 2,
      loggedAt: DateTime(2026, 1, 15, 8, 30),
    );
  }

  testWidgets(
    'composition table edit keeps 100g values when only time changes',
    (tester) async {
      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );
      await controller.addFood(compositionEntry());
      final original = controller.foodEntries.single;

      await openEditor(tester, controller: controller, entry: original);
      expect(find.text('食べた量 (g)'), findsOneWidget);
      expect(find.text('100gあたり · 131kcal'), findsOneWidget);
      expect(find.text('今回の摂取'), findsOneWidget);

      await pickAnotherDay(tester);
      await tester.tap(find.text('更新する'));
      await tester.pumpAndSettle();

      final saved = controller.foodEntries.single;
      expect(saved.unitType, FoodUnitType.g);
      expect(saved.baseAmount, 100);
      expect(saved.consumedAmount, 150);
      expect(saved.kcalPerBase, 131);
      expect(saved.totalKcal, closeTo(196.5, 0.01));
      expect(saved.sourceType, FoodEntrySource.mextSfct);
      expect(saved.officialFoodCode, '11111');
      expect(saved.mealGroupId, 'group-curry');
      expect(saved.mealGroupName, '夕食');
      expect(saved.sortOrder, 2);
      expect(saved.loggedAt, isNot(original.loggedAt));
    },
  );

  testWidgets('composition table amount edit changes intake only', (
    tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    await controller.addFood(compositionEntry());

    await openEditor(
      tester,
      controller: controller,
      entry: controller.foodEntries.single,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('food_quantity_field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('food_quantity_field')),
      '200',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新する'));
    await tester.pumpAndSettle();

    final saved = controller.foodEntries.single;
    expect(saved.unitType, FoodUnitType.g);
    expect(saved.baseAmount, 100);
    expect(saved.consumedAmount, 200);
    expect(saved.kcalPerBase, 131);
    expect(saved.totalKcal, closeTo(262, 0.01));
    expect(saved.mealGroupId, 'group-curry');
    expect(saved.sourceType, FoodEntrySource.mextSfct);
  });

  testWidgets('coach stores 200g of a 100g proposal as grams per 100g', (
    tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    const proposal = CoachMealProposal(
      headline: 'ごはん（精白米）',
      kcal: 156,
      proteinG: 2.5,
      fatG: 0.3,
      carbG: 37.1,
      components: [
        CoachMealComponent(
          foodCode: '01088',
          displayName: 'ごはん（精白米）',
          officialName: '精白米',
          units: 1,
          grams: 100,
          kcalPerUnit: 156,
          proteinPerUnit: 2.5,
          fatPerUnit: 0.3,
          carbPerUnit: 37.1,
        ),
      ],
    );
    final ids = await DailyCoachSession(
      controller: controller,
      slotStore: MemoryCoachSlotStore(),
    ).saveMeal(proposal, grams: const [200]);

    final saved = controller.foodEntries.single;
    expect(saved.id, ids.single);
    expect(saved.unitType, FoodUnitType.g);
    expect(saved.baseAmount, 100);
    expect(saved.consumedAmount, 200);
    expect(saved.kcalPerBase, closeTo(156, 0.01));
    expect(saved.totalKcal, closeTo(312, 0.01));
    expect(saved.sourceType, FoodEntrySource.mextSfct);
    expect(saved.mealGroupId, isNotNull);

    final mealGroupId = saved.mealGroupId;
    await openEditor(tester, controller: controller, entry: saved);
    expect(find.text('食べた量 (g)'), findsOneWidget);
    expect(find.text('100gあたり · 156kcal'), findsOneWidget);
    await tester.tap(find.text('更新する'));
    await tester.pumpAndSettle();

    final edited = controller.foodEntries.single;
    expect(edited.unitType, FoodUnitType.g);
    expect(edited.baseAmount, 100);
    expect(edited.consumedAmount, 200);
    expect(edited.kcalPerBase, closeTo(156, 0.01));
    expect(edited.totalKcal, closeTo(312, 0.01));
    expect(edited.mealGroupId, mealGroupId);
    expect(edited.mealGroupName, 'ごはん（精白米）');
    expect(edited.sourceType, FoodEntrySource.mextSfct);
  });

  testWidgets('new manual entry still saves one serving', (tester) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    await openEditor(tester, controller: controller);
    expect(find.text('食べた量（人前・個）'), findsOneWidget);
    expect(find.text('今回の摂取'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('food_name_field')),
      '手入力のスープ',
    );
    await tester.enterText(
      find.byKey(const ValueKey('macro_field_kcal')),
      '180',
    );
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('追加する'));
    await tester.pumpAndSettle();

    final saved = controller.foodEntries.single;
    expect(saved.unitType, FoodUnitType.serving);
    expect(saved.baseAmount, 1);
    expect(saved.consumedAmount, 1);
    expect(saved.kcalPerBase, 180);
    expect(saved.sourceType, FoodEntrySource.manual);
    expect(saved.officialFoodCode, isNull);
  });

  testWidgets('editing a manual entry without a food code keeps servings', (
    tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    await controller.addFood(
      FoodEntry(
        id: 'manual',
        name: '手入力のスープ',
        kcalPerBase: 80,
        baseAmount: 1,
        unitType: FoodUnitType.serving,
        consumedAmount: 2,
        sourceType: FoodEntrySource.manual,
        loggedAt: DateTime(2026, 1, 15, 12),
      ),
    );

    await openEditor(
      tester,
      controller: controller,
      entry: controller.foodEntries.single,
    );
    expect(find.text('食べた量（人前・個）'), findsOneWidget);
    expect(find.text('今回の摂取'), findsNothing);
    await tester.ensureVisible(
      find.byKey(const ValueKey('food_quantity_field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('food_quantity_field')),
      '4',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新する'));
    await tester.pumpAndSettle();

    final saved = controller.foodEntries.single;
    expect(saved.unitType, FoodUnitType.serving);
    expect(saved.baseAmount, 4);
    expect(saved.consumedAmount, 4);
    expect(saved.kcalPerBase, 160);
    expect(saved.totalKcal, closeTo(160, 0.01));
    expect(saved.sourceType, FoodEntrySource.manual);
    expect(saved.officialFoodCode, isNull);
  });

  testWidgets('saved food edit keeps its own base', (tester) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    await controller.addFood(
      FoodEntry(
        id: 'saved',
        name: 'ヨーグルト',
        kcalPerBase: 200,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 150,
        sourceType: FoodEntrySource.savedFood,
        savedFoodId: 'food-yogurt',
        loggedAt: DateTime(2026, 1, 15, 12),
      ),
    );

    await openEditor(
      tester,
      controller: controller,
      entry: controller.foodEntries.single,
    );
    expect(find.text('食べた量（g）'), findsOneWidget);
    expect(find.text('食べた量 (g)'), findsNothing);
    expect(find.text('100gあたり · 200kcal'), findsOneWidget);
    await tester.tap(find.text('更新する'));
    await tester.pumpAndSettle();

    final unchanged = controller.foodEntries.single;
    expect(unchanged.unitType, FoodUnitType.g);
    expect(unchanged.baseAmount, 100);
    expect(unchanged.consumedAmount, 150);
    expect(unchanged.kcalPerBase, 200);
    expect(unchanged.savedFoodId, 'food-yogurt');
    expect(unchanged.sourceType, FoodEntrySource.savedFood);

    await openEditor(tester, controller: controller, entry: unchanged);
    await tester.ensureVisible(
      find.byKey(const ValueKey('food_quantity_field')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('food_quantity_field')),
      '300',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('更新する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('今回の記録だけ変更'));
    await tester.pumpAndSettle();

    final scaled = controller.foodEntries.single;
    expect(scaled.unitType, FoodUnitType.g);
    expect(scaled.baseAmount, 200);
    expect(scaled.consumedAmount, 300);
    expect(scaled.kcalPerBase, 400);
    expect(scaled.totalKcal, closeTo(600, 0.01));
    expect(scaled.savedFoodId, 'food-yogurt');
  });
}
