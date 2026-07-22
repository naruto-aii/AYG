import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows consistency warning but still allows save', (
    WidgetTester tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );
    final service = OpenFoodFactsService(
      userAgent: 'AYG/test (test@example.com)',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FoodFormScreen(
                          controller: controller,
                          openFoodFactsService: service,
                        ),
                      ),
                    );
                  },
                  child: const Text('open form'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open form'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'テスト食品');
    await tester.enterText(fields.at(1), '200');
    await tester.enterText(fields.at(2), '10');
    await tester.enterText(fields.at(3), '5');
    await tester.enterText(fields.at(4), '10');
    await tester.pump();

    expect(find.textContaining('入力カロリーとPFCから計算した値に差があります'), findsOneWidget);

    final saveButton = find.widgetWithText(FilledButton, '保存');
    expect(saveButton, findsOneWidget);

    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.first.name, 'テスト食品');
    expect(controller.foodEntries.first.kcalPerUnit, 200);
    expect(find.text('open form'), findsOneWidget);
  });
}
