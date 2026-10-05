import 'package:ayg/models/official_food.dart';
import 'package:ayg/repositories/official_food_repository.dart';
import 'package:ayg/screens/meal_template/meal_template_form_screen.dart';
import 'package:ayg/screens/meal_template/template_food_search_screen.dart';
import 'package:ayg/services/template_food_pick.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

    expect(find.text('食品を検索'), findsOneWidget);
    expect(find.text('保存済み・公開食品・食品成分表から探す'), findsOneWidget);
    expect(find.text('保存済み食品から追加'), findsOneWidget);
    expect(find.text('公開食品から追加'), findsOneWidget);
    expect(find.text('手入力で追加'), findsOneWidget);
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
    await tester.tap(find.text('食品を検索'));
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
    await tester.tap(find.text('この食品を追加'));
    await tester.pumpAndSettle();

    expect(find.text('白米'), findsWidgets);
    expect(find.textContaining('100.0g'), findsOneWidget);
    expect(controller.foodEntries, isEmpty);
    controller.dispose();
  });
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
