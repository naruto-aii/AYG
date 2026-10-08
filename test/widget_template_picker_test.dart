import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/models/workout_template.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/meal_template_repository_base.dart';
import 'package:ayg/screens/settings/lock_screen_meal_screen.dart';
import 'package:ayg/screens/settings/widget_template_amount_screen.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/in_memory_workout_template_repository.dart';
import 'mocks/mock_authentication_repository.dart';

/// ウィジェットの枠: 食事か運動を選ぶ → 保存したテンプレートをプルダウンで選ぶ →
/// 構成ごとの量を入れる → 枠の中身になる。元のテンプレートは変えない。
void main() {
  final now = DateTime(2026, 10, 8, 9);

  MealTemplateItem food(String id, String name, double amount, int order) {
    return MealTemplateItem(
      itemId: id,
      name: name,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      kcalPerBase: 150,
      proteinPerBase: 5,
      fatPerBase: 1,
      carbPerBase: 30,
      consumedAmount: amount,
      sortOrder: order,
      snapshotSavedAt: now,
    );
  }

  Future<
    ({
      AppController controller,
      _MemoryGateway gateway,
      _MemoryMealTemplates meals,
      MockAuthenticationRepository auth,
    })
  >
  setUpController() async {
    final meals = _MemoryMealTemplates();
    meals.seed(
      MealTemplate(
        templateId: 'tpl-meal',
        ownerUserId: 'user-1',
        name: 'ジム後セット',
        normalizedName: 'ジム後セット',
        totalKcal: 0,
        totalProteinG: 0,
        totalFatG: 0,
        totalCarbG: 0,
        createdAt: now,
        updatedAt: now,
      ),
      [food('i1', 'ご飯', 150, 1), food('i2', '鶏むね', 100, 2)],
    );
    final workouts = InMemoryWorkoutTemplateRepository();
    await workouts.saveWithItems(
      template: WorkoutTemplate(
        templateId: 'tpl-run',
        ownerUserId: 'user-1',
        name: '朝ラン',
        normalizedName: '朝ラン',
        createdAt: now,
        updatedAt: now,
      ),
      items: [
        WorkoutTemplateItem(
          itemId: 'w1',
          name: 'ジョギング',
          activityId: 'jogging',
          durationMin: 30,
          sortOrder: 1,
        ),
        WorkoutTemplateItem(
          itemId: 'w2',
          name: '自分で入れた運動',
          durationMin: 10,
          sortOrder: 2,
        ),
      ],
    );
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final gateway = _MemoryGateway();
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
      mealTemplateRepository: meals,
      workoutTemplateRepository: workouts,
    );
    return (controller: controller, gateway: gateway, meals: meals, auth: auth);
  }

  testWidgets('a meal template is picked and each amount is entered', (
    tester,
  ) async {
    final setup = await setUpController();
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LockScreenMealScreen(controller: setup.controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('widget-slot-template-0-meal')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ジム後セット').last);
    await tester.pumpAndSettle();

    expect(find.byType(WidgetMealAmountScreen), findsOneWidget);
    expect(find.text('ご飯'), findsOneWidget);
    expect(find.text('鶏むね'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('widget-template-amount-0')),
      '200',
    );
    await tester.pump();
    expect(find.text('合計 約450kcal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('widget-template-amount-save')));
    await tester.pumpAndSettle();

    expect(find.byType(LockScreenMealScreen), findsOneWidget);
    expect(find.text('ご飯、鶏むね'), findsOneWidget);

    await tester.tap(find.byKey(const Key('lock-screen-meal-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    final saved = setup.gateway.saved!.homeButtons.first;
    expect(saved.kind, WidgetPatternKind.meal);
    expect(saved.contentName, 'ジム後セット');
    expect(saved.items.map((item) => item.name), ['ご飯', '鶏むね']);
    expect(saved.items.map((item) => item.consumedAmount), [200, 100]);
    expect(saved.items.first.kcalPerBase, 150);
    // 元のテンプレートは変わらない。
    final original = await setup.meals.getItems(
      ownerUserId: 'user-1',
      templateId: 'tpl-meal',
    );
    expect(original.first.consumedAmount, 150);
    setup.controller.dispose();
    await setup.auth.dispose();
  });

  testWidgets('a workout template keeps only widget-usable activities', (
    tester,
  ) async {
    final setup = await setUpController();
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LockScreenMealScreen(controller: setup.controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('widget-slot-kind-1-exercise')));
    await tester.pumpAndSettle();
    final picker = find.byKey(const Key('widget-slot-template-1-exercise'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('朝ラン').last);
    await tester.pumpAndSettle();

    expect(find.byType(WidgetWorkoutAmountScreen), findsOneWidget);
    expect(find.text('自分で入れた運動'), findsNothing);
    expect(find.textContaining('登録できない1件'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('widget-template-amount-0')),
      '3',
    );
    await tester.tap(find.byKey(const Key('widget-template-amount-save')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('lock-screen-meal-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('閉じる'));
    await tester.pumpAndSettle();

    final saved = setup.gateway.saved!.homeButtons[1];
    expect(saved.kind, WidgetPatternKind.exercise);
    expect(saved.exercises, hasLength(1));
    expect(saved.exercises.single.activityId, 'jogging');
    expect(saved.exercises.single.canRegister, isTrue);
    expect(saved.label, '朝ラン');
    setup.controller.dispose();
    await setup.auth.dispose();
  });

  testWidgets('with no templates the pulldown says so and stays closed', (
    tester,
  ) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: _MemoryGateway(),
      mealTemplateRepository: _MemoryMealTemplates(),
    );
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: LockScreenMealScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('保存したテンプレートはまだありません'), findsWidgets);
    controller.dispose();
    await auth.dispose();
  });
}

class _MemoryMealTemplates implements MealTemplateRepositoryBase {
  final List<MealTemplate> _templates = [];
  final Map<String, List<MealTemplateItem>> _items = {};

  void seed(MealTemplate template, List<MealTemplateItem> items) {
    _templates.add(template);
    _items[template.templateId] = items;
  }

  @override
  Future<List<MealTemplate>> getAll(String ownerUserId) async => [
    for (final template in _templates)
      if (template.ownerUserId == ownerUserId) template,
  ];

  @override
  Future<MealTemplate?> getById({
    required String ownerUserId,
    required String templateId,
  }) async {
    for (final template in _templates) {
      if (template.ownerUserId == ownerUserId &&
          template.templateId == templateId) {
        return template;
      }
    }
    return null;
  }

  @override
  Future<List<MealTemplateItem>> getItems({
    required String ownerUserId,
    required String templateId,
  }) async => [...?_items[templateId]];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MemoryGateway implements LockScreenMealGateway {
  LockScreenMealConfig config = LockScreenMealConfig.defaults();
  LockScreenMealConfig? saved;

  @override
  Future<void> acknowledge(List<String> registrationIds) async {}

  @override
  Future<bool> isPaid() async => true;

  @override
  Future<LockScreenMealConfig> loadConfig() async => config;

  @override
  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot) async {}

  @override
  Future<List<PendingLockScreenMeal>> readPending() async => const [];

  @override
  Future<void> saveConfig(LockScreenMealConfig config) async {
    saved = config;
    this.config = config;
  }

  @override
  Future<void> setPaid(bool isPaid) async {}
}
