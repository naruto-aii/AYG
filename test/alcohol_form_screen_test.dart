import 'package:ayg/screens/alcohol/alcohol_form_screen.dart';
import 'package:ayg/screens/food/food_tab_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AlcoholFormScreen', () {
    testWidgets('shows separate amount and unit fields with live preview', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: AlcoholFormScreen(controller: controller)),
      );

      expect(find.text('数量'), findsOneWidget);
      expect(find.text('単位'), findsOneWidget);
      expect(find.text('アルコール度数 (%)'), findsOneWidget);

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'ビール');
      await tester.enterText(fields.at(1), '500');
      await tester.enterText(fields.at(2), 'ml');
      await tester.enterText(fields.at(3), '5');
      await tester.pump();

      expect(find.textContaining('純アルコール量'), findsOneWidget);
      expect(find.textContaining('140'), findsWidgets);
      expect(find.text('摂取カロリーへの反映'), findsOneWidget);
    });

    testWidgets('shows manual pure alcohol field for non-ml unit', (
      tester,
    ) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(home: AlcoholFormScreen(controller: controller)),
      );

      await tester.enterText(find.byType(TextFormField).at(2), '缶');
      await tester.pump();

      expect(find.text('純アルコール量 (g)'), findsOneWidget);
      expect(find.text('mlで入力すると純アルコール量を自動計算できます'), findsOneWidget);
    });
  });

  group('FoodTabScreen alcohol entry point', () {
    testWidgets('shows food and alcohol add menu', (tester) async {
      final controller = AppController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: FoodTabScreen(
            controller: controller,
            openFoodFactsService: OpenFoodFactsService(userAgent: 'test-agent'),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.text('食事を追加'), findsAtLeast(1));
      expect(find.text('アルコールを追加'), findsOneWidget);
    });
  });
}
