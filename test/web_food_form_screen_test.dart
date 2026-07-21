import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/platform/web/web_barcode_support.dart';
import 'package:ayg/screens/food/web_food_form_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  OpenFoodFactsService createService() {
    return OpenFoodFactsService(userAgent: OpenFoodFactsConfig.userAgent);
  }

  testWidgets('shows camera, text input, and manual entry sections', (
    WidgetTester tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WebFoodFormScreen(
          controller: controller,
          openFoodFactsService: createService(),
        ),
      ),
    );

    expect(find.text('カメラでバーコードを読み取る'), findsOneWidget);
    expect(find.text('バーコード（テキスト入力）'), findsOneWidget);
    expect(find.text('手入力'), findsOneWidget);
    expect(find.text('食品名'), findsOneWidget);
    expect(find.text('保存'), findsOneWidget);
  });

  testWidgets('shows fallback message when camera scan is unavailable', (
    WidgetTester tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WebFoodFormScreen(
          controller: controller,
          openFoodFactsService: createService(),
          barcodeScanAvailabilityChecker: () => false,
        ),
      ),
    );

    await tester.tap(find.text('カメラでバーコードを読み取る'));
    await tester.pumpAndSettle();

    expect(find.text('カメラを利用できません。バーコード番号を入力してください。'), findsOneWidget);
    expect(find.text('バーコード（テキスト入力）'), findsOneWidget);
    expect(find.text('手入力'), findsOneWidget);
  });

  testWidgets('keeps manual entry after Open Food Facts failure', (
    WidgetTester tester,
  ) async {
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: WebFoodFormScreen(
          controller: controller,
          openFoodFactsService: createService(),
          barcodeLookupBuilder: (service) =>
              WebBarcodeLookup(_FailingOpenFoodFactsService()),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '3017620422003');
    await tester.tap(find.text('バーコードで検索'));
    await tester.pumpAndSettle();

    expect(find.text('通信に失敗しました。手入力をご利用ください。'), findsOneWidget);
    expect(find.text('手入力'), findsOneWidget);
    expect(find.text('食品名'), findsOneWidget);
  });
}

class _FailingOpenFoodFactsService extends OpenFoodFactsService {
  _FailingOpenFoodFactsService()
    : super(userAgent: 'AYG/0.1 (test@example.com)');

  @override
  Future<({FoodLookupResult? data, OffLookupFailure? failure})> fetchByBarcode(
    String barcode,
  ) async {
    return (data: null, failure: OffLookupFailure.network);
  }
}
