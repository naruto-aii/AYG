import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/food/meal_add_layout_mock.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final loader = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();

  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = config['packages'] as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'material_symbols_icons',
  );
  final root = Uri.parse(entry['rootUri'] as String);
  final configUri = Directory.current.uri.resolve(
    '.dart_tool/package_config.json',
  );
  final resolved = configUri.resolveUri(root);
  final file = File(
    '${resolved.toFilePath()}/lib/fonts/MaterialSymbolsRounded.ttf',
  );
  final symbols = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  symbols.addFont(
    Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
  );
  await symbols.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('current meal-add screen and the layout mock', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
    directory.createSync(recursive: true);
    final controller = AppController();
    addTearDown(controller.dispose);

    await _capture(
      tester,
      FoodFormScreen(
        controller: controller,
        openFoodFactsService: OpenFoodFactsService(
          userAgent: 'AYG/test (test@example.com)',
        ),
      ),
      File('${directory.path}/meal_add_current.png'),
      find.text('写真で登録'),
    );
    expect(find.text('手入力'), findsOneWidget);
    expect(find.text('バーコード'), findsOneWidget);
    expect(find.text('食品を探す'), findsOneWidget);
    expect(find.text('テンプレート'), findsOneWidget);

    await _capture(
      tester,
      const MealAddLayoutMock(),
      File('${directory.path}/meal_add_mock.png'),
      find.text('写真で登録 (β)'),
    );
    expect(find.text('その他の方法'), findsOneWidget);
    expect(find.text('成分表'), findsOneWidget);
    expect(find.text('手入力'), findsNothing);
  });
}

Future<void> _capture(
  WidgetTester tester,
  Widget screen,
  File file,
  Finder visible,
) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(key: key, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  expect(visible, findsWidgets);
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 1),
  );
  expect(bytes, isNotNull);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
  expect(image!.width, greaterThan(0));
}
