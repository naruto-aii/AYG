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
    await tester.binding.setSurfaceSize(const Size(430, 932));
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
              expect(dish.ingredients.first.grams, 119);
              expect(dish.ingredients.first.kcal, 129);
              expect(dish.kcal, 603);
              expect(
                dish.ingredients.fold<int>(0, (sum, item) => sum + item.kcal),
                dish.kcal,
              );
              expect(dish.gapKcal, 47);
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
    expect(find.text('あと＋47kcal'), findsNWidgets(2));
    expect(find.textContaining('P 目標より3.5g多い'), findsOneWidget);
    expect(find.textContaining('F あと＋0.9g'), findsOneWidget);
    expect(find.text('603kcal　P 35.5g　F 17.1g　C 75.7g'), findsOneWidget);
    expect(find.text('603kcal　P 35.2g　F 17.8g　C 75.9g'), findsOneWidget);
    expect(find.byKey(const Key('cook_ingredient_on_hand_鶏むね肉')), findsOneWidget);
    expect(find.text('119g'), findsWidgets);
    expect(find.byKey(const Key('cook_kcal_on_hand_鶏むね肉')), findsOneWidget);
    expect(find.text('160g'), findsWidgets);
    expect(find.text('鶏むね肉の照り焼き、味噌汁、ごはんの温め'), findsOneWidget);
    expect(find.text('鶏むね肉とキャベツの味噌炒め、味噌汁、ごはんの温め'), findsOneWidget);
    expect(find.text('調理の目安 19分'), findsOneWidget);
    expect(find.text('1. 鶏むね肉を一口大に切る。'), findsOneWidget);
    tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);
    await tester.pumpAndSettle();
    _expectFullyVisible(tester, '鶏むね肉の照り焼き、味噌汁、ごはんの温め');
    await _write(tester, boundary, File('${directory.path}/results.png'));
    await tester.ensureVisible(find.text('鶏むね肉とキャベツの味噌炒め、味噌汁、ごはんの温め'));
    await tester.pumpAndSettle();
    _expectFullyVisible(tester, '鶏むね肉とキャベツの味噌炒め、味噌汁、ごはんの温め');
    await tester.ensureVisible(find.byKey(const Key('cook_register_extra')));
    await tester.pumpAndSettle();
    _expectRectInside(
      tester.getRect(find.byKey(const Key('cook_register_extra'))),
    );

    await tester.ensureVisible(find.byKey(const Key('cook_register_on_hand')));
    await tester.tap(find.byKey(const Key('cook_register_on_hand')));
    await tester.pumpAndSettle();
    expect(find.text('食事に追加しました'), findsOneWidget);
    expect(find.text('鶏むね肉 119g　129kcal'), findsOneWidget);
    expect(find.text('603kcal　P 35.5g　F 17.1g　C 75.7g'), findsOneWidget);
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
  bool assumed = false,
}) {
  return {
    'name': name,
    'grams': grams,
    'kcal': kcal,
    'protein_g': protein,
    'fat_g': fat,
    'carb_g': carb,
    'source': 'db',
    'food_code': code,
    'official_name': name,
    'extra': extra,
    'assumed': assumed,
  };
}

Map<String, Object?> _payload() {
  // 鶏むね肉＋ごはん、夕食 650/32/18/75。合計は材料の行の和。
  return {
    'ok': true,
    'retried': false,
    'calls': const <Map<String, Object?>>[],
    'patterns': [
      {
        'kind': 'on_hand',
        'name': '鶏むね肉の照り焼き、味噌汁、ごはんの温め',
        'minutes': 19,
        'steps': [
          '鶏むね肉を一口大に切る。',
          'フライパンを中火にし、サラダ油14gを熱して鶏むね肉を5分焼く。',
          'しょうゆ12gとみりん10gと砂糖6gを加えて3分絡め、照りを出す。',
          '火を止めて器に盛る。',
          '鍋に水を300mlと顆粒だし6gを入れて4分煮立たせる。',
          '味噌12gを溶き入れる。',
          'しょうゆ4gを加えて2分煮て火を止める。',
          '器に盛る。',
          'ごはん160gを茶碗によそう。',
          '塩1gをふって混ぜ、電子レンジで2分温める。',
          '3分置いてから出す。',
        ],
        'extras': <String>[],
        'kcal': 603,
        'protein_g': 35.5,
        'fat_g': 17.1,
        'carb_g': 75.7,
        'gap_kcal': 47,
        'within_tolerance': true,
        'ingredients': [
          _row(name: '鶏むね肉', grams: 119, kcal: 129, protein: 27.7, fat: 1.8, carb: 0.1, code: '11220'),
          _row(name: 'サラダ油', grams: 14, kcal: 129, protein: 0, fat: 14, carb: 0, code: '14006', assumed: true),
          _row(name: 'しょうゆ', grams: 12, kcal: 9, protein: 0.9, fat: 0, carb: 0.9, code: '17007', assumed: true),
          _row(name: 'みりん', grams: 10, kcal: 24, protein: 0, fat: 0, carb: 4.3, code: '16025', assumed: true),
          _row(name: '砂糖', grams: 6, kcal: 23, protein: 0, fat: 0, carb: 6, code: '03003', assumed: true),
          _row(name: '顆粒だし', grams: 6, kcal: 14, protein: 1.1, fat: 0.1, carb: 2.2, code: '17028', assumed: true),
          _row(name: '味噌', grams: 12, kcal: 22, protein: 1.5, fat: 0.7, carb: 2.5, code: '17045', assumed: true),
          _row(name: 'しょうゆ', grams: 4, kcal: 3, protein: 0.3, fat: 0, carb: 0.3, code: '17007', assumed: true),
          _row(name: 'ごはん', grams: 160, kcal: 250, protein: 4, fat: 0.5, carb: 59.4, code: '01088'),
          _row(name: '塩', grams: 1, kcal: 0, protein: 0, fat: 0, carb: 0, code: '17012', assumed: true),
        ],
      },
      {
        'kind': 'extra',
        'name': '鶏むね肉とキャベツの味噌炒め、味噌汁、ごはんの温め',
        'minutes': 18,
        'steps': [
          '鶏むね肉とキャベツを食べやすく切る。',
          'フライパンを中火にし、サラダ油14gを熱して鶏むね肉を4分焼く。',
          'キャベツを加えて3分炒め、味噌12gと砂糖6gと料理酒8gを絡める。',
          '火を止めて器に盛る。',
          '鍋に水を300mlと顆粒だし6gを入れて4分煮立たせる。',
          '味噌12gを溶き入れる。',
          'しょうゆ4gを加えて2分煮て火を止める。',
          '器に盛る。',
          'ごはん156gを茶碗によそう。',
          '塩1gをふって混ぜ、電子レンジで2分温める。',
          '3分置いてから出す。',
        ],
        'extras': ['キャベツ'],
        'kcal': 603,
        'protein_g': 35.2,
        'fat_g': 17.8,
        'carb_g': 75.9,
        'gap_kcal': 47,
        'within_tolerance': true,
        'ingredients': [
          _row(name: '鶏むね肉', grams: 111, kcal: 120, protein: 25.9, fat: 1.7, carb: 0.1, code: '11220'),
          _row(name: 'キャベツ', grams: 77, kcal: 18, protein: 1, fat: 0.1, carb: 4, code: '06061', extra: true),
          _row(name: 'サラダ油', grams: 14, kcal: 129, protein: 0, fat: 14, carb: 0, code: '14006', assumed: true),
          _row(name: '味噌', grams: 12, kcal: 22, protein: 1.5, fat: 0.7, carb: 2.5, code: '17045', assumed: true),
          _row(name: '砂糖', grams: 6, kcal: 23, protein: 0, fat: 0, carb: 6, code: '03003', assumed: true),
          _row(name: '料理酒', grams: 8, kcal: 9, protein: 0, fat: 0, carb: 0.4, code: '17138', assumed: true),
          _row(name: '顆粒だし', grams: 6, kcal: 14, protein: 1.1, fat: 0.1, carb: 2.2, code: '17028', assumed: true),
          _row(name: '味噌', grams: 12, kcal: 22, protein: 1.5, fat: 0.7, carb: 2.5, code: '17045', assumed: true),
          _row(name: 'しょうゆ', grams: 4, kcal: 3, protein: 0.3, fat: 0, carb: 0.3, code: '17007', assumed: true),
          _row(name: 'ごはん', grams: 156, kcal: 243, protein: 3.9, fat: 0.5, carb: 57.9, code: '01088'),
          _row(name: '塩', grams: 1, kcal: 0, protein: 0, fat: 0, carb: 0, code: '17012', assumed: true),
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
  expect(image!.width, 1290);
  expect(image.height, 2796);
}

void _expectFullyVisible(WidgetTester tester, String text) {
  _expectRectInside(tester.getRect(find.text(text)));
}

void _expectRectInside(Rect rect) {
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(rect.bottom, lessThanOrEqualTo(932));
}
