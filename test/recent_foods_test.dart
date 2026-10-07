import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/food/recent_foods_screen.dart';
import 'package:ayg/screens/home/home_screen.dart';
import 'package:ayg/services/nutrition_engine.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/recent_foods.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  final now = DateTime(2026, 10, 4, 12);

  FoodEntry food({
    required String id,
    required String name,
    required DateTime loggedAt,
    double consumed = 200,
    String? code,
    String? memo,
    String? mealGroupId,
  }) {
    return FoodEntry(
      id: id,
      name: name,
      kcalPerBase: 100,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      consumedAmount: consumed,
      officialFoodCode: code,
      memo: memo,
      mealGroupId: mealGroupId,
      loggedAt: loggedAt,
    );
  }

  test('the last 3 days keep one row per food and the latest amount', () {
    final foods = recentFoods([
      food(
        id: 'old',
        name: 'ささみ',
        code: '11229',
        consumed: 100,
        loggedAt: DateTime(2026, 10, 2, 8),
      ),
      food(
        id: 'new',
        name: 'ささみ',
        code: '11229',
        consumed: 200,
        loggedAt: DateTime(2026, 10, 3, 8),
      ),
      food(id: 'too-old', name: '納豆', loggedAt: DateTime(2026, 10, 1, 8)),
      food(id: 'rice', name: '白米', loggedAt: DateTime(2026, 10, 4, 8)),
    ], now);

    expect(foods.map((item) => item.latest.id), ['rice', 'new']);
    expect(formatFoodAmount(foods[1].latest), '200g');
  });

  test(
    'repeating a food keeps the amount and drops the memo and meal group',
    () async {
      final controller = _controller(plus: true);
      addTearDown(controller.dispose);
      final source = food(
        id: 'source',
        name: 'ささみ',
        consumed: 200,
        memo: '少し多かったから明日は150',
        mealGroupId: 'meal',
        loggedAt: DateTime(2026, 10, 3, 8),
      );
      controller.foodEntries.add(source);

      final added = await controller.repeatRecentFood(source, loggedAt: now);

      expect(added, isTrue);
      expect(controller.foodEntries, hasLength(2));
      final created = controller.foodEntries.last;
      expect(created.id, isNot('source'));
      expect(created.consumedAmount, 200);
      expect(created.memo, isNull);
      expect(created.mealGroupId, isNull);
      expect(created.loggedAt, now);
    },
  );

  test('without Calonavi Plus the repeat and the memo are refused', () async {
    final controller = _controller(plus: false);
    addTearDown(controller.dispose);
    final source = food(
      id: 'source',
      name: 'ささみ',
      loggedAt: DateTime(2026, 10, 3, 8),
    );
    controller.foodEntries.add(source);

    expect(await controller.repeatRecentFood(source), isFalse);
    expect(await controller.updateFoodMemo(source, '明日は150'), isFalse);
    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.single.memo, isNull);
  });

  test(
    'a template memo is stored on each food only for Calonavi Plus',
    () async {
      final plus = _controller(plus: true);
      addTearDown(plus.dispose);
      await plus.registerFoodMealFromDrafts(
        mealGroupName: 'ささみ定食',
        items: [_draft()],
        loggedAt: now,
        memo: '少し多かったから明日は150',
      );
      expect(plus.foodEntries.single.memo, '少し多かったから明日は150');

      final free = _controller(plus: false);
      addTearDown(free.dispose);
      await free.registerFoodMealFromDrafts(
        mealGroupName: 'ささみ定食',
        items: [_draft()],
        loggedAt: now,
        memo: '少し多かったから明日は150',
      );
      expect(free.foodEntries.single.memo, isNull);
    },
  );

  test(
    'a later registration of the same food does not keep the memo',
    () async {
      final plus = _controller(plus: true);
      addTearDown(plus.dispose);
      await plus.registerFoodMealFromDrafts(
        mealGroupName: 'ささみ定食',
        items: [_draft()],
        loggedAt: DateTime(2026, 10, 3, 8),
        memo: '少し多かったから明日は150',
      );
      await plus.registerFoodMealFromDrafts(
        mealGroupName: 'ささみ定食',
        items: [_draft()],
        loggedAt: now,
      );

      expect(plus.foodEntries.first.memo, '少し多かったから明日は150');
      expect(plus.foodEntries.last.memo, isNull);

      final added = await plus.repeatRecentFood(
        plus.foodEntries.first,
        loggedAt: now,
      );
      expect(added, isTrue);
      expect(plus.foodEntries.last.memo, isNull);
      expect(plus.foodEntries.first.memo, '少し多かったから明日は150');
    },
  );

  test('memo survives the remote row', () {
    final entry = food(
      id: 'e1',
      name: 'ささみ',
      memo: '少し多かったから明日は150',
      loggedAt: now,
    );
    final row = FoodMasterRowMapper.foodEntryToRow(entry, userId: 'u1');
    final parsed = FoodMasterRowMapper.foodEntryFromRow(row);
    expect(parsed.memo, '少し多かったから明日は150');
    expect(row['memo'], '少し多かったから明日は150');
  });

  testWidgets(
    'the same amount registers immediately and a different amount asks',
    (tester) async {
      final controller = _controller(plus: true);
      addTearDown(controller.dispose);
      controller.foodEntries.add(
        food(
          id: 'source',
          name: 'ささみ',
          consumed: 200,
          loggedAt: DateTime(2026, 10, 3, 8),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: RecentFoodsScreen(controller: controller, now: now),
        ),
      );
      await tester.tap(find.text('ささみ'));
      await tester.pumpAndSettle();
      expect(find.text('前回と同じ量（200g）で登録しますか？'), findsOneWidget);

      await tester.tap(find.text('違う'));
      await tester.pumpAndSettle();
      expect(find.text('量を入力'), findsOneWidget);
      expect(find.text('まとめて登録'), findsNothing);

      await tester.tap(find.text('戻る'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ささみ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('同じ'));
      await tester.pumpAndSettle();

      expect(controller.foodEntries, hasLength(2));
      expect(controller.foodEntries.last.consumedAmount, 200);
    },
  );

  testWidgets('home keeps recent foods and memos behind Calonavi Plus', (
    tester,
  ) async {
    final controller = _homeController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('直近3日の食品'));
    await tester.tap(find.text('直近3日の食品'));
    await tester.pumpAndSettle();
    expect(find.text('直近3日の食品からの追加は、カロナビ+です。'), findsOneWidget);
    expect(find.text('前回と同じ量（200g）で登録しますか？'), findsNothing);

    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('メモ'));
    await tester.tap(find.text('メモ'));
    await tester.pumpAndSettle();
    expect(find.text('食品のメモは、カロナビ+です。'), findsOneWidget);
  });
}

MealTemplateItemDraft _draft() {
  return const MealTemplateItemDraft(
    name: 'ささみ',
    baseAmount: 100,
    unitType: FoodUnitType.g,
    kcalPerBase: 100,
    consumedAmount: 200,
    sortOrder: 1,
  );
}

AppController _controller({required bool plus}) {
  return AppController(
    nutritionEngine: NutritionEngine(),
    healthRepository: MockHealthRepository(isAvailable: false),
    subscriptionRepository: _Plus(plus),
  );
}

AppController _homeController() {
  final controller = _controller(plus: false);
  controller.setProfile(
    UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 170,
      weightKg: 60,
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
      targetWeightKg: 60,
      targetDate: DateTime(2026, 12, 1),
    ),
  );
  controller.foodEntries.add(
    FoodEntry(
      id: 'today',
      name: 'ささみ',
      kcalPerBase: 100,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      consumedAmount: 200,
      loggedAt: DateTime.now(),
    ),
  );
  return controller;
}

class _Plus extends UnavailableSubscriptionRepository {
  _Plus(this.active);

  final bool active;

  @override
  bool get isPlusActive => active;

  @override
  Stream<bool> get plusChanges => const Stream.empty();
}
