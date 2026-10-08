import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/screens/coach/cook_coach_screen.dart';
import 'package:ayg/services/cook_coach_client.dart';
import 'package:ayg/services/cook_coach_target.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/utils/meal_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _loadFonts() async {
  final zen = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    zen.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await zen.load();

  final icons = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  final iconFile = File(_materialSymbolsFontPath());
  icons.addFont(
    Future<ByteData>.value(ByteData.sublistView(iconFile.readAsBytesSync())),
  );
  await icons.load();
}

String _materialSymbolsFontPath() {
  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = config['packages'] as List<dynamic>;
  final pkg = packages.cast<Map<String, dynamic>>().firstWhere(
    (item) => item['name'] == 'material_symbols_icons',
  );
  var root = Uri.parse(pkg['rootUri'] as String);
  if (!root.path.endsWith('/')) {
    root = root.replace(path: '${root.path}/');
  }
  return root.resolve('lib/fonts/MaterialSymbolsRounded.ttf').toFilePath();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  const now = CookCoachMealTarget(
    slot: MealSlot.dinner,
    kcal: 650,
    proteinG: 32,
    fatG: 18,
    carbG: 75,
    remainingKcal: 650,
    remainingProteinG: 32,
    remainingFatG: 18,
    remainingCarbG: 75,
  );

  testWidgets('cook coach input, result gap, and saved meal', (tester) async {
    final preferred = Directory('/opt/cursor/artifacts/screenshots/cook-coach');
    final directory = preferred.parent.existsSync()
        ? preferred
        : Directory.systemTemp.createTempSync('cook-coach-shots');
    directory.createSync(recursive: true);
    final boundary = GlobalKey();

    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: boundary,
          child: CookCoachScreen(
            now: DateTime(2026, 10, 8, 18),
            target: now,
            client: CookCoachClient(invoke: (_) async => _payload()),
            onRegister: (dish, slot) async {
              expect(slot, MealSlot.dinner);
              expect(dish.ingredients.first.grams, 113);
              expect(dish.ingredients.first.kcal, 122);
              expect(dish.kcal, 631);
              expect(
                dish.ingredients.fold<int>(0, (sum, item) => sum + item.kcal),
                dish.kcal,
              );
              expect(dish.gapKcal, 19);
              expect(dish.withinTolerance, isTrue);
              return const ['entry-1'];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('夕食の目標 650kcal（P 32g / F 18g / C 75g）'), findsOneWidget);
    await tester.tap(find.byKey(const Key('cook_choice_鶏むね肉')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_choice_ごはん')));
    await tester.pumpAndSettle();
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/input.png'));

    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();
    expect(find.text('目標の範囲に入っています'), findsNWidgets(2));
    expect(find.text('あと＋19kcal'), findsOneWidget);
    expect(find.text('あと＋9kcal'), findsOneWidget);
    expect(find.textContaining('P 目標より0.9g多い'), findsOneWidget);
    expect(find.textContaining('F あと＋0.7g'), findsOneWidget);
    expect(find.text('631kcal　P 32.9g　F 17.3g　C 79.9g'), findsOneWidget);
    expect(find.text('641kcal　P 32.4g　F 19.3g　C 78.4g'), findsOneWidget);
    expect(find.text('鶏むね肉 113g　122kcal　成分表'), findsOneWidget);
    expect(find.text('サラダ油 15g　138kcal　成分表'), findsOneWidget);
    expect(find.text('しょうゆ 10g　7kcal　成分表'), findsOneWidget);
    expect(find.text('しょうゆ 4g　3kcal　成分表'), findsOneWidget);
    expect(find.text('鶏むね肉の照り焼き丼'), findsOneWidget);
    expect(find.text('鶏むね肉と木綿豆腐の照り焼き丼'), findsOneWidget);
    expect(find.text('1. 鶏むね肉113gを一口大に切る'), findsOneWidget);
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pumpAndSettle();
    _expectFullyVisible(tester, '鶏むね肉の照り焼き丼');
    _expectFullyVisible(tester, '鶏むね肉と木綿豆腐の照り焼き丼');
    _expectFullyVisible(
      tester,
      'P 目標より0.4g多い　F 目標より1.3g多い　C 目標より3.4g多い',
    );
    _expectRectInside(
      tester.getRect(find.byKey(const Key('cook_register_extra'))),
    );
    await _write(tester, boundary, File('${directory.path}/results.png'));

    await tester.ensureVisible(find.byKey(const Key('cook_register_on_hand')));
    await tester.tap(find.byKey(const Key('cook_register_on_hand')));
    await tester.pumpAndSettle();
    expect(find.text('食事に追加しました'), findsOneWidget);
    expect(find.text('鶏むね肉 113g　122kcal'), findsOneWidget);
    expect(find.text('631kcal　P 32.9g　F 17.3g　C 79.9g'), findsOneWidget);
    expect(find.byKey(const Key('cook_saved_totals')), findsOneWidget);
    await _write(tester, boundary, File('${directory.path}/saved.png'));
  });
}

Map<String, Object?> _row({
  required String name,
  required int grams,
  required int kcal,
  required double protein,
  required double fat,
  required double carb,
  String? code,
  bool extra = false,
}) {
  return {
    'name': name,
    'grams': grams,
    'kcal': kcal,
    'protein_g': protein,
    'fat_g': fat,
    'carb_g': carb,
    'source': code == null ? 'ai' : 'db',
    'food_code': code,
    'official_name': code == null ? null : name,
    'extra': extra,
  };
}

Map<String, Object?> _payload() {
  // 成分表のグラム最適化と同じ行。合計は行の和。差は 650 から引いた値。
  return {
    'ok': true,
    'retried': false,
    'calls': [
      {'input_tokens': 400, 'output_tokens': 180, 'latency_ms': 280},
    ],
    'patterns': [
      {
        'kind': 'on_hand',
        'name': '鶏むね肉の照り焼き丼',
        'steps': [
          '鶏むね肉113gを一口大に切る',
          'フライパンを中火にし、サラダ油15gを熱し、鶏むね肉を3分ずつ焼く',
          'しょうゆ10gとみりん13gを加えて1分絡め、中まで火を通す',
          '夕食として、ごはん198gを盛ってのせる',
        ],
        'extras': <String>[],
        'kcal': 420,
        'protein_g': 36,
        'fat_g': 4,
        'carb_g': 52,
        'gap_kcal': 12,
        'gap_protein_g': 1,
        'gap_fat_g': 0,
        'gap_carb_g': 2,
        'within_tolerance': false,
        'ingredients': [
          _row(name: '鶏むね肉', grams: 113, kcal: 122, protein: 27.1, fat: 1.7, carb: 0, code: '11226'),
          _row(name: 'ごはん', grams: 198, kcal: 333, protein: 5, fat: 0.6, carb: 73.5, code: '1080'),
          _row(name: 'サラダ油', grams: 15, kcal: 138, protein: 0, fat: 15, carb: 0, code: '1400'),
          _row(name: 'しょうゆ', grams: 10, kcal: 7, protein: 0.8, fat: 0, carb: 0.8, code: '1901'),
          _row(name: 'みりん', grams: 13, kcal: 31, protein: 0, fat: 0, carb: 5.6, code: '1902'),
        ],
      },
      {
        'kind': 'extra',
        'name': '鶏むね肉と木綿豆腐の照り焼き丼',
        'steps': [
          '鶏むね肉62gを一口大に切る。木綿豆腐186gを2cm角に切る。キャベツ42gを食べやすく切る',
          'フライパンを中火にし、サラダ油10gを熱し、鶏むね肉を3分ずつ焼く',
          'キャベツを加えて2分炒め、しょうゆ4gとみりん15gを絡めて1分火を通す',
          '夕食として、ごはん177gを盛ってのせる',
        ],
        'extras': ['木綿豆腐', 'キャベツ'],
        'kcal': 180,
        'gap_kcal': 80,
        'within_tolerance': false,
        'ingredients': [
          _row(name: '鶏むね肉', grams: 62, kcal: 67, protein: 14.9, fat: 0.9, carb: 0, code: '11226'),
          _row(name: 'ごはん', grams: 177, kcal: 297, protein: 4.4, fat: 0.5, carb: 65.7, code: '1080'),
          _row(name: '木綿豆腐', grams: 186, kcal: 136, protein: 12.3, fat: 7.8, carb: 3.7, code: '401', extra: true),
          _row(name: 'キャベツ', grams: 42, kcal: 10, protein: 0.5, fat: 0.1, carb: 2.2, code: '602', extra: true),
          _row(name: 'サラダ油', grams: 10, kcal: 92, protein: 0, fat: 10, carb: 0, code: '1400'),
          _row(name: 'しょうゆ', grams: 4, kcal: 3, protein: 0.3, fat: 0, carb: 0.3, code: '1901'),
          _row(name: 'みりん', grams: 15, kcal: 36, protein: 0, fat: 0, carb: 6.5, code: '1902'),
        ],
      },
    ],
  };
}

Future<void> _write(WidgetTester tester, GlobalKey key, File file) async {
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 3),
  );
  expect(bytes, isNotNull);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
  expect(image!.width, 1179);
  expect(image.height, 2556);
}

void _expectFullyVisible(WidgetTester tester, String text) {
  _expectRectInside(tester.getRect(find.text(text)));
}

void _expectRectInside(Rect rect) {
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(852));
}
