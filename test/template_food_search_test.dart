import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template_draft.dart';
import 'package:ayg/models/official_food.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/meal_template/meal_template_form_screen.dart';
import 'package:ayg/screens/meal_template/template_food_search_screen.dart';
import 'package:ayg/services/ai_food_lookup_client.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/template_food_pick.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/settings_row.dart';
import 'package:ayg/widgets/food/ai_food_lookup_row.dart';
import 'package:ayg/widgets/food/combined_food_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/isar_test_helper.dart';
import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('official food becomes a template row with the chosen amount', () {
    const match = OfficialFoodMatch(
      foodCode: '01083',
      name: '白米',
      baseAmount: 100,
      unitType: 'g',
      kcal: 168,
      proteinG: 2.5,
      fatG: 0.3,
      carbG: 37.1,
    );

    final item = templateItemFromOfficialFood(
      match,
      consumedAmount: 150,
      sortOrder: 2,
    );

    expect(item.name, '白米');
    expect(item.baseAmount, 100);
    expect(item.consumedAmount, 150);
    expect(item.kcalPerBase, 168);
    expect(item.proteinPerBase, 2.5);
    expect(item.sortOrder, 2);
    expect(item.savedFoodId, isNull);
  });

  test(
    'confirmed AI food uses the same amount and nutrition as a meal entry',
    () {
      const capture = ConfirmedFoodCapture(
        name: '筑前煮',
        amountText: '200g',
        kcal: 280,
        proteinG: 12,
        fatG: 8,
        carbG: 40,
      );
      final item = templateItemFromConfirmedFood(capture, sortOrder: 1);
      final entry = foodEntryFromPhotoMeal(
        id: 'food-1',
        name: capture.name,
        amountText: capture.amountText,
        kcal: capture.kcal,
        proteinG: capture.proteinG,
        fatG: capture.fatG,
        carbG: capture.carbG,
        loggedAt: DateTime(2026, 10, 21),
      );

      expect(item.name, '筑前煮');
      expect(item.baseAmount, entry.baseAmount);
      expect(item.consumedAmount, entry.consumedAmount);
      expect(item.unitType, entry.unitType);
      expect(item.kcalPerBase, entry.kcalPerBase);
      expect(item.proteinPerBase, entry.proteinPerBase);
      expect(item.fatPerBase, entry.fatPerBase);
      expect(item.carbPerBase, entry.carbPerBase);
      expect(item.consumedAmount, 200);
      expect(item.unitType, FoodUnitType.g);
      expect(item.savedFoodId, isNull);
    },
  );

  testWidgets('template add menu includes food search with the other sources', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MealTemplateFormScreen(controller: controller),
      ),
    );

    await tester.ensureVisible(find.text('食品を追加'));
    await tester.tap(find.text('食品を追加'));
    await tester.pumpAndSettle();

    expect(find.text('手入力'), findsOneWidget);
    expect(find.text('保存済み食品から追加'), findsOneWidget);
    expect(find.text('食品検索'), findsOneWidget);
    expect(find.text('保存済み・定番の食品・公開食品から探す'), findsOneWidget);
    expect(find.text('公開食品から追加'), findsNothing);
    expect(find.text('食品を検索'), findsNothing);
    controller.dispose();
  });

  testWidgets('search returns an official food instead of logging a meal', (
    tester,
  ) async {
    final controller = AppController();
    OfficialFoodMatch? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<Object?>(
                  MaterialPageRoute<Object?>(
                    builder: (context) => TemplateFoodSearchScreen(
                      controller: controller,
                      officialFoods: const _RiceFoods(),
                    ),
                  ),
                );
                if (result is OfficialFoodMatch) {
                  picked = result;
                }
              },
              child: const Text('開く'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('template-food-search-field')),
        matching: find.byType(TextField),
      ),
      '白米',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final rice = find.widgetWithText(SettingsRow, '白米');
    await tester.ensureVisible(rice);
    expect(rice, findsOneWidget);
    expect(controller.foodEntries, isEmpty);

    await tester.tap(rice);
    await tester.pumpAndSettle();

    expect(picked?.foodCode, '01083');
    expect(controller.foodEntries, isEmpty);
    controller.dispose();
  });

  testWidgets('choosing an official food adds it to the template', (
    tester,
  ) async {
    final controller = AppController();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MealTemplateFormScreen(
          controller: controller,
          officialFoods: const _RiceFoods(),
        ),
      ),
    );
    await tester.ensureVisible(find.text('食品を追加'));
    await tester.tap(find.text('食品を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食品検索'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('template-food-search-field')),
        matching: find.byType(TextField),
      ),
      '白米',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    final rice = find.widgetWithText(SettingsRow, '白米');
    await tester.ensureVisible(rice);
    await tester.tap(rice);
    await tester.pumpAndSettle();

    expect(find.text('この食品を追加'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('template-official-amount')),
      '200',
    );
    await tester.tap(find.text('この食品を追加'));
    await tester.pumpAndSettle();

    expect(find.text('白米'), findsWidgets);
    expect(find.textContaining('200.0g'), findsOneWidget);
    // 168 kcal / 100g × 200g
    expect(find.text('336'), findsWidgets);
    expect(controller.foodEntries, isEmpty);
    controller.dispose();
  });

  testWidgets('template search offers the same AI and chain lookup as meals', (
    tester,
  ) async {
    var calls = 0;
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MealTemplateFormScreen(
          controller: controller,
          searchOverrides: _emptySearch(),
          aiLookup: AiFoodLookupClient(
            invoke: (_) async {
              calls += 1;
              return null;
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('食品を追加'));
    await tester.tap(find.text('食品を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食品検索'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chain-food-lookup-row')), findsOneWidget);
    expect(find.text('外食・コンビニ'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('template-food-search-field')),
        matching: find.byType(TextField),
      ),
      '筑前煮',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ai-food-lookup-empty')));
    expect(find.text(AiFoodLookupRow.label), findsOneWidget);
    expect(find.text('「筑前煮」を自分で入力する'), findsOneWidget);

    await tester.tap(find.text(AiFoodLookupRow.label));
    await tester.pumpAndSettle();
    expect(find.text('AIで探すはカロナビ+の機能です'), findsOneWidget);
    expect(calls, 0);
    expect(controller.foodEntries, isEmpty);
  });

  testWidgets('AI search from a template adds kcal, PFC, and amount', (
    tester,
  ) async {
    final controller = AppController(subscriptionRepository: _ActivePlus());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MealTemplateFormScreen(
          controller: controller,
          searchOverrides: _emptySearch(),
          aiLookup: AiFoodLookupClient(
            invoke: (body) async {
              expect(body, {'query': '筑前煮'});
              return {
                'ok': true,
                'usage_id': 'usage-template',
                'cache_hit': false,
                'candidates': [
                  {
                    'name': '筑前煮',
                    'amount': '200g',
                    'kcal': 280,
                    'protein_g': 12,
                    'fat_g': 8,
                    'carb_g': 40,
                    'known_product': false,
                  },
                ],
              };
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('食品を追加'));
    await tester.tap(find.text('食品を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食品検索'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('template-food-search-field')),
        matching: find.byType(TextField),
      ),
      '筑前煮',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AiFoodLookupRow.label));
    await tester.tap(find.text(AiFoodLookupRow.label));
    await tester.pumpAndSettle();
    expect(controller.foodEntries, isEmpty);
    await tester.tap(find.text('筑前煮'));
    await tester.pumpAndSettle();
    expect(find.text('この内容で追加'), findsOneWidget);
    expect(find.text('この内容で登録'), findsNothing);
    await tester.tap(find.text('この内容で追加'));
    await tester.pumpAndSettle();

    expect(find.text('筑前煮'), findsWidgets);
    expect(find.textContaining('200.0g'), findsOneWidget);
    expect(find.text('280'), findsWidgets);
    expect(find.textContaining('タンパク質 12g'), findsOneWidget);
    expect(find.textContaining('脂質 8g'), findsOneWidget);
    expect(find.textContaining('炭水化物 40g'), findsOneWidget);
    expect(controller.foodEntries, isEmpty);
  });

  test(
    'a confirmed AI item saves and recalls without logging a meal first',
    () async {
      final harness = await IsarTestHarness.create();
      addTearDown(harness.dispose);
      final controller = _templateController(harness, plus: true);
      addTearDown(controller.dispose);
      const capture = ConfirmedFoodCapture(
        name: '筑前煮',
        amountText: '200g',
        kcal: 280,
        proteinG: 12,
        fatG: 8,
        carbG: 40,
      );

      final saved = await controller.saveMealTemplate(
        draft: MealTemplateDraft(
          name: '夜の定番',
          items: [templateItemFromConfirmedFood(capture, sortOrder: 1)],
        ),
      );

      expect(controller.foodEntries, isEmpty);
      expect(saved.totalKcal, 280);
      final bundle = await controller.getMealTemplateWithItems(
        saved.templateId,
      );
      final item = bundle!.items.single;
      expect(item.name, '筑前煮');
      expect(item.baseAmount, 200);
      expect(item.consumedAmount, 200);
      expect(item.unitType, FoodUnitType.g);
      expect(item.kcalPerBase, 280);
      expect(item.proteinPerBase, 12);
      expect(item.fatPerBase, 8);
      expect(item.carbPerBase, 40);

      final applied = await controller.applyMealTemplate(
        templateId: saved.templateId,
      );
      expect(applied.success, isTrue);
      expect(controller.foodEntries, hasLength(1));
      expect(controller.foodEntries.single.name, '筑前煮');
      expect(controller.foodEntries.single.kcalPerBase, 280);
      expect(controller.foodEntries.single.proteinPerBase, 12);
      expect(controller.foodEntries.single.fatPerBase, 8);
      expect(controller.foodEntries.single.carbPerBase, 40);
      expect(controller.foodEntries.single.consumedAmount, 200);
      expect(controller.foodEntries.single.baseAmount, 200);
    },
  );

  testWidgets('chain lookup from a template adds the estimate as an item', (
    tester,
  ) async {
    final controller = AppController(subscriptionRepository: _ActivePlus());
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MealTemplateFormScreen(
          controller: controller,
          searchOverrides: _emptySearch(),
          aiLookup: AiFoodLookupClient(
            invoke: (body) async {
              expect(body, {'query': '牛丼'});
              return {
                'ok': true,
                'usage_id': 'usage-chain',
                'cache_hit': false,
                'candidates': [
                  {
                    'name': '牛丼',
                    'amount': '1人前',
                    'kcal': 700,
                    'protein_g': 25,
                    'fat_g': 20,
                    'carb_g': 90,
                    'known_product': true,
                  },
                ],
              };
            },
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('食品を追加'));
    await tester.tap(find.text('食品を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食品検索'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('chain-food-lookup-row')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('chain-food-lookup-field')),
      '牛丼',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('推定する'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('牛丼'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('この内容で追加'));
    await tester.pumpAndSettle();

    expect(find.text('牛丼'), findsWidgets);
    expect(find.textContaining('1.01食分'), findsOneWidget);
    expect(find.text('700'), findsWidgets);
    expect(find.textContaining('タンパク質 25g'), findsOneWidget);
    expect(controller.foodEntries, isEmpty);
  });

  testWidgets('an empty template search can still enter the name by hand', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MealTemplateFormScreen(
          controller: controller,
          searchOverrides: _emptySearch(),
        ),
      ),
    );

    await tester.ensureVisible(find.text('食品を追加'));
    await tester.tap(find.text('食品を追加'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食品検索'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('template-food-search-field')),
        matching: find.byType(TextField),
      ),
      '名前だけ',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('「名前だけ」を自分で入力する'));
    await tester.tap(find.text('「名前だけ」を自分で入力する'));
    await tester.pumpAndSettle();

    expect(find.text('手入力食品'), findsOneWidget);
    expect(find.widgetWithText(TextField, '名前だけ'), findsOneWidget);
    expect(controller.foodEntries, isEmpty);
  });
}

CombinedFoodSearchOverrides _emptySearch() {
  return CombinedFoodSearchOverrides(
    debounce: Duration.zero,
    searchSaved: (_) async => const [],
    searchOfficial: (_) async => const OfficialFoodSearchResult(matches: []),
    searchPublic: (_) async => const [],
  );
}

AppController _templateController(
  IsarTestHarness harness, {
  required bool plus,
}) {
  return AppController(
    subscriptionRepository: plus ? _ActivePlus() : null,
    healthRepository: MockHealthRepository(isAvailable: false),
    authenticationRepository: MockAuthenticationRepository(
      currentUser: const AuthUser(
        id: 'user-template',
        email: 'template@test.com',
      ),
    ),
    dataSyncRepository: MockDataSyncRepository(),
    userRepository: harness.userRepository,
    settingsRepository: harness.settingsRepository,
    foodRepository: harness.foodRepository,
    exerciseRepository: harness.exerciseRepository,
    weightRepository: harness.weightRepository,
    savedFoodRepository: harness.savedFoodRepository,
    mealTemplateRepository: harness.mealTemplateRepository,
  );
}

class _ActivePlus extends UnavailableSubscriptionRepository {
  @override
  bool get isPlusActive => true;
}

class _RiceFoods implements OfficialFoodRepository {
  const _RiceFoods();

  @override
  Future<List<OfficialFoodMatch>> search(String query, {int limit = 30}) async {
    if (!query.contains('白米')) {
      return const [];
    }
    return const [
      OfficialFoodMatch(
        foodCode: '01083',
        name: '白米',
        baseAmount: 100,
        unitType: 'g',
        kcal: 168,
        proteinG: 2.5,
        fatG: 0.3,
        carbG: 37.1,
      ),
    ];
  }
}
