import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/meal_template/meal_template_list_screen.dart';
import 'package:ayg/screens/saved_food/saved_food_list_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/screens/shell/main_shell_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'prototype_food_fixtures.dart';
import 'prototype_meal_template_fixtures.dart';
import 'prototype_public_food_search_page.dart';
import 'prototype_ui5_fixtures.dart';

const _desktopSize = Size(1440, 900);
const _screenshotKey = ValueKey('web_desktop_screenshot_root');

Future<void> _capturePng(WidgetTester tester, String path) async {
  await tester.binding.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(_screenshotKey),
    );
    final image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
}

Future<void> _pumpDesktopApp(WidgetTester tester, Widget child) async {
  await tester.binding.setSurfaceSize(_desktopSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: RepaintBoundary(
        key: _screenshotKey,
        child: MediaQuery(
          data: const MediaQueryData(size: _desktopSize),
          child: SizedBox(
            width: _desktopSize.width,
            height: _desktopSize.height,
            child: child,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('web_home_desktop_v1', (tester) async {
    final controller = await createPrototypeUi5Controller();
    final authRepository = createPrototypeUi5AuthRepository();
    final openFoodFactsService = OpenFoodFactsService(
      userAgent: OpenFoodFactsConfig.userAgent,
    );

    await _pumpDesktopApp(
      tester,
      MainShellScreen(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
        authenticationRepository: authRepository,
      ),
    );

    expect(find.text('ホーム'), findsWidgets);
    await _capturePng(tester, 'screenshots/web_home_desktop_v1.png');
  });

  testWidgets('web_food_form_desktop_v1', (tester) async {
    final controller = await createPrototypeUi5Controller();
    final openFoodFactsService = OpenFoodFactsService(
      userAgent: OpenFoodFactsConfig.userAgent,
    );

    await _pumpDesktopApp(
      tester,
      FoodFormScreen(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
      ),
    );

    expect(find.text('食事を追加'), findsOneWidget);
    await _capturePng(tester, 'screenshots/web_food_form_desktop_v1.png');
  });

  testWidgets('web_saved_food_desktop_v1', (tester) async {
    final controller = await createPrototypeSavedFoodListController();
    final openFoodFactsService = OpenFoodFactsService(
      userAgent: OpenFoodFactsConfig.userAgent,
    );

    await _pumpDesktopApp(
      tester,
      SavedFoodListScreen(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('サラダチキン'), findsOneWidget);
    await _capturePng(tester, 'screenshots/web_saved_food_desktop_v1.png');
  });

  testWidgets('web_public_food_desktop_v1', (tester) async {
    final controller = createPrototypePublicSearchController();
    final openFoodFactsService = OpenFoodFactsService(
      userAgent: OpenFoodFactsConfig.userAgent,
    );

    await _pumpDesktopApp(
      tester,
      PrototypePublicFoodSearchPage(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('公開食品検索'), findsOneWidget);
    await _capturePng(tester, 'screenshots/web_public_food_desktop_v1.png');
  });

  testWidgets('web_meal_template_desktop_v1', (tester) async {
    final controller = createPrototypeMealTemplateController();

    await _pumpDesktopApp(
      tester,
      MealTemplateListScreen(controller: controller),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('食事テンプレート'), findsOneWidget);
    await _capturePng(tester, 'screenshots/web_meal_template_desktop_v1.png');
  });

  testWidgets('web_settings_desktop_v1', (tester) async {
    final controller = await createPrototypeUi5Controller();
    final authRepository = createPrototypeUi5AuthRepository();
    final openFoodFactsService = OpenFoodFactsService(
      userAgent: OpenFoodFactsConfig.userAgent,
    );

    await _pumpDesktopApp(
      tester,
      SettingsScreen(
        controller: controller,
        authenticationRepository: authRepository,
        openFoodFactsService: openFoodFactsService,
        hideHealthSettings: true,
      ),
    );

    expect(find.text('設定'), findsOneWidget);
    await _capturePng(tester, 'screenshots/web_settings_desktop_v1.png');
  });
}
