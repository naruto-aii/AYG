import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/models/macro_field.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/food/web_food_form_screen.dart';
import 'package:ayg/screens/saved_food/saved_food_form_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'macro_nutrition_test_helpers.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FoodFormScreen macro auto-fill', () {
    late AppController appController;
    late OpenFoodFactsService offService;

    setUp(() {
      appController = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );
      offService = OpenFoodFactsService(
        userAgent: OpenFoodFactsConfig.userAgent,
      );
    });

    tearDown(() => appController.dispose());

    Future<void> pumpForm(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FoodFormScreen(
            controller: appController,
            openFoodFactsService: offService,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('case1: P F C -> kcal 165 without save', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.kcal), '165');
      expect(find.textContaining('（自動）'), findsOneWidget);
    });

    testWidgets('case2: kcal F C -> P 12.0', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.fat, '8');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.protein), '12.0');
    });

    testWidgets('case3: kcal P C -> F 4.4', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.protein, '20');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.fat), '4.4');
    });

    testWidgets('case4: kcal P F -> C 12.0', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.protein, '20');
      await enterMacro(tester, MacroField.fat, '8');
      expect(macroText(tester, MacroField.carb), '12.0');
    });

    testWidgets('two values do not auto-fill third', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      expect(macroText(tester, MacroField.kcal), isEmpty);
    });

    testWidgets('order C P F auto-fills kcal', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.carb, '20');
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      expect(macroText(tester, MacroField.kcal), '165');
    });

    testWidgets('order kcal C F auto-fills P', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.carb, '20');
      await enterMacro(tester, MacroField.fat, '8');
      expect(macroText(tester, MacroField.protein), '12.0');
    });

    testWidgets('order F kcal P auto-fills C', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.fat, '8');
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.protein, '20');
      expect(macroText(tester, MacroField.carb), '12.0');
    });

    testWidgets('empty kcal focus does not block auto-fill', (tester) async {
      await pumpForm(tester);
      await tapMacroField(tester, MacroField.kcal);
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.kcal), '165');
    });

    testWidgets('deleting field clears stale auto and recalculates', (
      tester,
    ) async {
      await pumpForm(tester);
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

    testWidgets('partial decimal 12. does not auto-fill', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      await tester.enterText(find.byKey(ValueKey('macro_field_carb')), '12.');
      await tester.pump();
      expect(macroText(tester, MacroField.kcal), isEmpty);
    });

    testWidgets('zero is valid for auto calculation', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '36');
      await enterMacro(tester, MacroField.protein, '0');
      await enterMacro(tester, MacroField.fat, '0');
      expect(macroText(tester, MacroField.carb), '9.0');
    });
  });

  group('SavedFoodFormScreen macro auto-fill', () {
    late AppController appController;

    setUp(() {
      appController = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );
    });

    tearDown(() => appController.dispose());

    Future<void> pumpForm(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: SavedFoodFormScreen(controller: appController)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('case1: P F C -> kcal 165', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.kcal), '165');
    });

    testWidgets('case2: kcal F C -> P 12.0', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.fat, '8');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.protein), '12.0');
    });

    testWidgets('case3: kcal P C -> F 4.4', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.protein, '20');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.fat), '4.4');
    });

    testWidgets('case4: kcal P F -> C 12.0', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.protein, '20');
      await enterMacro(tester, MacroField.fat, '8');
      expect(macroText(tester, MacroField.carb), '12.0');
    });
  });

  group('WebFoodFormScreen macro auto-fill', () {
    late AppController appController;
    late OpenFoodFactsService offService;

    setUp(() {
      appController = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );
      offService = OpenFoodFactsService(
        userAgent: OpenFoodFactsConfig.userAgent,
      );
    });

    tearDown(() => appController.dispose());

    Future<void> pumpForm(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WebFoodFormScreen(
            controller: appController,
            openFoodFactsService: offService,
            barcodeScanAvailabilityChecker: () => false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('case1: P F C -> kcal 165 without save', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.kcal), '165');
    });

    testWidgets('case2: kcal F C -> P 12.0', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.fat, '8');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.protein), '12.0');
    });

    testWidgets('case3: kcal P C -> F 4.4', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.protein, '20');
      await enterMacro(tester, MacroField.carb, '20');
      expect(macroText(tester, MacroField.fat), '4.4');
    });

    testWidgets('case4: kcal P F -> C 12.0', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.kcal, '200');
      await enterMacro(tester, MacroField.protein, '20');
      await enterMacro(tester, MacroField.fat, '8');
      expect(macroText(tester, MacroField.carb), '12.0');
    });

    testWidgets('order C P F auto-fills kcal', (tester) async {
      await pumpForm(tester);
      await enterMacro(tester, MacroField.carb, '20');
      await enterMacro(tester, MacroField.protein, '10');
      await enterMacro(tester, MacroField.fat, '5');
      expect(macroText(tester, MacroField.kcal), '165');
    });

    testWidgets('deleting field clears stale auto value', (tester) async {
      await pumpForm(tester);
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
