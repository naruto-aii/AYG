import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/widgets/design/design_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OpenFoodFactsService service() {
    return OpenFoodFactsService(userAgent: 'AYG/test (test@example.com)');
  }

  Future<void> pumpHost(WidgetTester tester, AppController controller) async {
    final foods = service();
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
                        openFoodFactsService: foods,
                        guideFirstMeal: controller.shouldOfferFirstMealGuide,
                      ),
                    ),
                  );
                },
                child: const Text('食事を開く'),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> openForm(WidgetTester tester) async {
    await tester.tap(find.text('食事を開く'));
    await tester.pumpAndSettle();
  }

  Future<void> saveMeal(WidgetTester tester) async {
    await tester.enterText(
      find.byKey(const ValueKey('food_name_field')),
      'ごはん',
    );
    await tester.enterText(
      find.byKey(const ValueKey('macro_field_kcal')),
      '200',
    );
    await tester.enterText(
      find.byKey(const ValueKey('macro_field_protein')),
      '4',
    );
    await tester.enterText(find.byKey(const ValueKey('macro_field_fat')), '1');
    await tester.enterText(
      find.byKey(const ValueKey('macro_field_carb')),
      '40',
    );
    await tester.pumpAndSettle();
    final saveSwitch = find.byType(Switch);
    await tester.scrollUntilVisible(
      saveSwitch,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(saveSwitch);
    await tester.pumpAndSettle();
    final save = find.text('追加する');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();
  }

  testWidgets('saving one meal ends the first meal guide', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.offerFirstMealGuide();
    expect(controller.shouldOfferFirstMealGuide, isTrue);

    await pumpHost(tester, controller);
    await openForm(tester);

    expect(find.byKey(FoodFormScreen.firstMealGuideKey), findsOneWidget);
    expect(find.text('今日の食事を1件登録'), findsOneWidget);
    expect(find.text('運動'), findsNothing);
    expect(find.text('食事を追加'), findsOneWidget);
    expect(
      tester
          .widget<DesignButton>(find.widgetWithText(DesignButton, '閉じる'))
          .showTrailingIcon,
      isFalse,
    );
    expect(controller.shouldOfferFirstMealGuide, isFalse);

    await saveMeal(tester);

    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.single.name, 'ごはん');
    expect(find.byKey(FoodFormScreen.firstMealGuideKey), findsNothing);

    await openForm(tester);
    expect(find.text('食事を追加'), findsOneWidget);
    expect(find.byKey(FoodFormScreen.firstMealGuideKey), findsNothing);
  });

  testWidgets('closing the first meal guide does not show it again', (
    tester,
  ) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.offerFirstMealGuide();

    await pumpHost(tester, controller);
    await openForm(tester);
    await tester.tap(find.widgetWithText(DesignButton, '閉じる'));
    await tester.pumpAndSettle();

    expect(find.byKey(FoodFormScreen.firstMealGuideKey), findsNothing);
    expect(find.text('食事を追加'), findsOneWidget);
    expect(controller.foodEntries, isEmpty);

    await tester.tap(find.text('戻る'));
    await tester.pumpAndSettle();
    await openForm(tester);
    expect(find.byKey(FoodFormScreen.firstMealGuideKey), findsNothing);
  });
}
