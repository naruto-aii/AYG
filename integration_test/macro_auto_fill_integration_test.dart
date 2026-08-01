import 'package:ayg/app.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/macro_field.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/food/food_tab_screen.dart';
import 'package:ayg/screens/saved_food/saved_food_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/macro_nutrition_test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpOnboardedApp(WidgetTester tester) async {
    final setup = await createOnboardedAppController();
    await tester.pumpWidget(
      AygApp(
        controller: setup.controller,
        openFoodFactsService: setup.openFoodFactsService,
        healthRepository: setup.healthRepository,
        authenticationRepository: setup.authRepository,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.navHome), findsWidgets);
  }

  Future<void> openFoodFormFromHome(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.navHome));
    await tester.pumpAndSettle();
    await tester.tap(find.text('食事追加'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('macro_field_kcal')), findsOneWidget);
  }

  Future<void> openFoodFormFromFoodTab(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.navFood));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(FoodTabScreen),
        matching: find.byType(FloatingActionButton),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('macro_field_kcal')), findsOneWidget);
  }

  Future<void> openSavedFoodCreate(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.navSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.settingsFoodMaster));
    await tester.pumpAndSettle();
    await tester.tap(find.text('マイ食品'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.byType(SavedFoodFormScreen), findsOneWidget);
  }

  group('iOS Simulator macro auto-fill navigation paths', () {
    testWidgets('home path: P F C -> kcal 165 before save', (tester) async {
      await pumpOnboardedApp(tester);
      await openFoodFormFromHome(tester);

      await tapMacroField(tester, MacroField.kcal);
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      await enterMacro(tester, MacroField.carb, '20');

      expect(macroText(tester, MacroField.kcal), '165');
      expect(find.textContaining('（自動）'), findsOneWidget);
    });

    testWidgets('food tab path: kcal F C -> P 12.0 before save', (
      tester,
    ) async {
      await pumpOnboardedApp(tester);
      await openFoodFormFromFoodTab(tester);

      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.fat, '8');
      await enterMacro(tester, MacroField.carb, '20');

      expect(macroText(tester, MacroField.protein), '12.0');
    });

    testWidgets('saved food create: kcal P F -> C 12.0 before save', (
      tester,
    ) async {
      await pumpOnboardedApp(tester);
      await openSavedFoodCreate(tester);

      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.protein, '20');
      await enterMacro(tester, MacroField.fat, '8');

      expect(macroText(tester, MacroField.carb), '12.0');
    });

    testWidgets('input order C P F still auto-fills kcal', (tester) async {
      await pumpOnboardedApp(tester);
      await openFoodFormFromHome(tester);

      await enterMacro(tester, MacroField.carb, '20');
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');

      expect(macroText(tester, MacroField.kcal), '165');
    });

    testWidgets('deleting one manual field clears stale auto value', (
      tester,
    ) async {
      await pumpOnboardedApp(tester);
      await openFoodFormFromHome(tester);

      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.kcal), '165');

      await tester.enterText(find.byKey(ValueKey('macro_field_carb')), '');
      await tester.pump();
      expect(macroText(tester, MacroField.kcal), isEmpty);

      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.kcal), '165');
    });
  });
}
