import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/food/photo_meal_confirm_screen.dart';
import 'package:ayg/screens/food/photo_meal_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

Future<void> _loadZenMaru() async {
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
  await _loadSymbols();
}

Future<void> _loadSymbols() async {
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
  final loader = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  loader.addFont(
    Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
  );
  await loader.load();
}

class _FixedPhotoSource implements MealPhotoSource {
  _FixedPhotoSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<Uint8List?> pickFromLibrary() async => bytes;

  @override
  Future<Uint8List?> takePhoto() async => bytes;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadZenMaru);

  testWidgets('photo entry and confirm screens', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
    directory.createSync(recursive: true);
    final controller = AppController();
    addTearDown(controller.dispose);

    final photo = img.Image(width: 640, height: 480);
    img.fill(photo, color: img.ColorRgb8(214, 122, 62));
    final jpeg = Uint8List.fromList(img.encodeJpg(photo, quality: 70));

    final entryKey = await _capture(
      tester,
      PhotoMealScreen(
        controller: controller,
        loggedAt: DateTime(2026, 10, 8, 12),
        client: PhotoMealClient(invoke: (_) async => null),
        source: _FixedPhotoSource(jpeg),
      ),
      File('${directory.path}/photo_meal_entry.png'),
      find.text('写真で登録 (β)'),
      scrollTo: find.text('補足'),
    );
    expect(
      find.textContaining('これはAIの推定です。登録の前に確認して、数値を直せます。'),
      findsOneWidget,
    );
    expect(find.text('任意です。入れると精度が上がります。'), findsOneWidget);
    expect(find.text('任意です。グラム・個数・杯数など、できるだけ正確に入れると精度が上がります。'), findsOneWidget);
    expect(find.text('油多め'), findsOneWidget);
    expect(find.text('皮なし'), findsOneWidget);
    expect(
      find.text('任意です。例）油を多めに使った、脂身が多い部位など、写真で分かりにくい特徴を書くと精度が上がります。'),
      findsOneWidget,
    );
    final note = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const ValueKey('photo_meal_note')),
        matching: find.byType(TextField),
      ),
    );
    await tester.ensureVisible(find.text('油多め'));
    await tester.tap(find.text('油多め'));
    await tester.pump();
    expect(note.controller?.text, '油多め');
    await tester.ensureVisible(find.text('皮なし'));
    await tester.tap(find.text('皮なし'));
    await tester.pump();
    expect(note.controller?.text, '油多め、皮なし');
    final scrollable = find
        .descendant(
          of: find.byType(PhotoMealScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(scrollable, const Offset(0, 1600));
    await tester.pumpAndSettle();

    await tester.tap(find.text('写真を撮る'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    await _write(
      tester,
      File('${directory.path}/photo_meal_selected.png'),
      key: entryKey,
    );

    await _capture(
      tester,
      PhotoMealConfirmScreen(
        controller: controller,
        loggedAt: DateTime(2026, 10, 8, 12),
        hadUserDishName: false,
        analysis: const PhotoMealAnalysis(
          usageId: null,
          estimate: PhotoMealEstimate(
            dishName: '親子丼',
            amount: '1杯',
            kcal: 700,
            proteinG: 30,
            fatG: 25,
            carbG: 80,
            confidence: 0.6,
            items: [],
          ),
        ),
      ),
      File('${directory.path}/photo_meal_confirm.png'),
      find.text('推定の確認'),
    );
    expect(find.text('これはAIの推定です。登録の前に確認して、数値を直せます。'), findsOneWidget);
    expect(find.text('700'), findsOneWidget);
  });

  testWidgets('meal add shows 撮る, 探す, and その他', (tester) async {
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
      File('${directory.path}/meal_add_groups.png'),
      find.text('その他'),
    );
    expect(find.text('撮る'), findsOneWidget);
    expect(find.text('探す'), findsOneWidget);
    expect(find.text('写真で登録 (β)'), findsOneWidget);
    expect(find.text('食品を探す'), findsOneWidget);
    expect(find.text('手入力'), findsOneWidget);
    expect(find.text('バーコード'), findsOneWidget);
    expect(find.text('テンプレート'), findsOneWidget);
  });
}

Future<GlobalKey> _capture(
  WidgetTester tester,
  Widget screen,
  File file,
  Finder visible, {
  Finder? scrollTo,
}) async {
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
  if (scrollTo != null) {
    final scrollable = find
        .descendant(
          of: find.byType(PhotoMealScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    for (var i = 0; i < 8 && scrollTo.hitTestable().evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -280));
      await tester.pumpAndSettle();
    }
    expect(scrollTo.hitTestable(), findsOneWidget);
    await tester.drag(scrollable, const Offset(0, -180));
    await tester.pumpAndSettle();
  }
  await _write(tester, file, key: key);
  return key;
}

Future<void> _write(
  WidgetTester tester,
  File file, {
  required GlobalKey key,
}) async {
  final boundary = key;
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(boundary, pixelRatio: 1),
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
