import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/data/coach_food_catalog.dart';
import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/screens/food/photo_meal_screen.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
import 'package:ayg/services/personal_coach_planner.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 実機（iPhone 15 Pro Max など）と同じ 430×932pt を 3 倍で描く（1290×2796）。
/// 拡大ではなく、3 倍の解像度でそのまま描画する。
///
/// SHOT_DIR と SHOT_TAG（before / after）を渡したときだけ動く。
/// PHOTO_SOURCE は端末の縦写真（EXIF 付き JPEG）。
final _env = Platform.environment;
final _dir = _env['SHOT_DIR'];
final _tag = _env['SHOT_TAG'];
final _photo = _env['PHOTO_SOURCE'];

Future<void> _loadFonts() async {
  final zen = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    zen.addFont(
      Future<ByteData>.value(ByteData.sublistView(File(path).readAsBytesSync())),
    );
  }
  await zen.load();
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final pkg = (config['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .firstWhere((item) => item['name'] == 'material_symbols_icons');
  var root = Uri.parse(pkg['rootUri'] as String);
  if (!root.path.endsWith('/')) {
    root = root.replace(path: '${root.path}/');
  }
  final configUri = Directory.current.uri.resolve('.dart_tool/package_config.json');
  final font = File(
    configUri.resolveUri(root).resolve('lib/fonts/MaterialSymbolsRounded.ttf').toFilePath(),
  );
  final icons = FontLoader('packages/material_symbols_icons/MaterialSymbolsRounded');
  icons.addFont(Future<ByteData>.value(ByteData.sublistView(font.readAsBytesSync())));
  await icons.load();
}

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
}

Future<void> _shoot(
  WidgetTester tester,
  Widget screen,
  String name, {
  Future<void> Function()? settle,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(key: key, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  if (settle != null) {
    await settle();
  }
  final bytes = await tester.runAsync(() => pngBytesFromBoundary(key, pixelRatio: 3));
  final file = File('$_dir/${name}_$_tag.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  });
  expect([image!.width, image.height], [1290, 2796]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);
  final skip = _dir == null || _tag == null;

  testWidgets('写真で登録: 縦写真のプレビュー', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final raw = File(_photo!).readAsBytesSync();
    final jpeg = (await tester.runAsync(() async => compressMealPhoto(raw)))!;
    File('$_dir/photo_preview_sent.jpg').writeAsBytesSync(jpeg);
    await _shoot(
      tester,
      PhotoMealScreen(
        controller: controller,
        loggedAt: DateTime(2026, 10, 9, 12),
        client: PhotoMealClient(invoke: (_) async => null),
        initialJpeg: jpeg,
      ),
      'photo_preview',
      settle: () async {
        await tester.runAsync(() async {
          for (final element in find.byType(Image).evaluate()) {
            final widget = element.widget as Image;
            await precacheImage(widget.image, element);
          }
        });
        await tester.pumpAndSettle();
      },
    );
  }, skip: skip || _photo == null);

  testWidgets('パーソナルコーチ: 自炊コーチの入口', (tester) async {
    final now = DateTime(2026, 10, 9, 8, 30);
    final plans = planCoachDay(
      foods: CoachFoodCatalog.stocks,
      excludedFoodCodes: const {},
      remainingKcal: 1500,
      now: now,
    );
    await _shoot(
      tester,
      DailyCoachScreen(
        introStore: _SeenIntro(),
        now: now,
        load: () async => DailyCoachLoadResult(
          status: DailyCoachStatus.ready,
          focus: DailyCoachFocus.meals,
          plans: plans,
        ),
      ),
      'cook_coach_entry',
    );
    expect(find.byKey(const Key('cook_coach_entry')), findsOneWidget);
  }, skip: skip);
}
