import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/screens/coach/cook_coach_screen.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/cook_coach.dart';
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
  setUp(() {
    AiDataConsent.override = MemoryAiDataConsent(granted: true);
  });
  tearDown(() {
    AiDataConsent.override = null;
  });

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

    await tester.binding.setSurfaceSize(const Size(390, 1200));
    tester.view.devicePixelRatio = 1;
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
              expect(dish.ingredients.first.grams, 150);
              expect(dish.kcal, 420);
              return const ['entry-1'];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('夕食の目標 650kcal（P 32g / F 18g / C 75g）'), findsOneWidget);
    await _write(tester, boundary, File('${directory.path}/input.png'));

    await tester.tap(find.byKey(const Key('cook_choice_鶏むね肉')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('cook_choice_ごはん')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();
    expect(find.text('目標の範囲に入っています'), findsOneWidget);
    expect(find.text('あと＋12kcal'), findsOneWidget);
    expect(find.text('あと＋80kcal'), findsOneWidget);
    expect(find.text('鶏むね肉 150g　162kcal　成分表'), findsOneWidget);
    expect(find.text('自家製つゆ 15g　12kcal　AIの目安'), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(390, 2000));
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/results.png'));

    await tester.ensureVisible(find.byKey(const Key('cook_register_on_hand')));
    await tester.tap(find.byKey(const Key('cook_register_on_hand')));
    await tester.pumpAndSettle();
    expect(find.text('食事に追加しました'), findsOneWidget);
    expect(find.text('鶏むね肉 150g　162kcal'), findsOneWidget);
    expect(find.byKey(const Key('cook_saved_totals')), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/saved.png'));
  });
}

Map<String, Object?> _payload() {
  return {
    'ok': true,
    'retried': false,
    'calls': [
      {'input_tokens': 400, 'output_tokens': 180, 'latency_ms': 280},
    ],
    'patterns': [
      {
        'kind': 'on_hand',
        'name': '鶏むねとごはん',
        'steps': ['鶏肉は中まで火を通す', 'ごはんを盛る'],
        'extras': <String>[],
        'kcal': 420,
        'protein_g': 36,
        'fat_g': 4,
        'carb_g': 52,
        'gap_kcal': 12,
        'gap_protein_g': 1,
        'gap_fat_g': 0,
        'gap_carb_g': 2,
        'within_tolerance': true,
        'ingredients': [
          {
            'name': '鶏むね肉',
            'grams': 150,
            'kcal': 162,
            'protein_g': 36,
            'fat_g': 2,
            'carb_g': 0,
            'source': 'db',
            'food_code': '11226',
            'official_name': '鶏むね肉',
          },
          {
            'name': 'ごはん',
            'grams': 140,
            'kcal': 235,
            'protein_g': 4,
            'fat_g': 0,
            'carb_g': 52,
            'source': 'db',
            'food_code': '1080',
            'official_name': 'ごはん',
          },
        ],
      },
      {
        'kind': 'extra',
        'name': '豆腐を足した煮物',
        'steps': ['肉と豆腐を中まで加熱する'],
        'extras': ['豆腐'],
        'kcal': 180,
        'protein_g': 20,
        'fat_g': 4,
        'carb_g': 8,
        'gap_kcal': 80,
        'gap_protein_g': 8,
        'gap_fat_g': 4,
        'gap_carb_g': 40,
        'within_tolerance': false,
        'ingredients': [
          {
            'name': '鶏むね肉',
            'grams': 80,
            'kcal': 86,
            'protein_g': 19,
            'fat_g': 1,
            'carb_g': 0,
            'source': 'db',
            'food_code': '11226',
            'official_name': '鶏むね肉',
          },
          {
            'name': '自家製つゆ',
            'grams': 15,
            'kcal': 12,
            'protein_g': 1,
            'fat_g': 0,
            'carb_g': 2,
            'source': 'ai',
          },
        ],
      },
    ],
  };
}

Future<void> _write(WidgetTester tester, GlobalKey key, File file) async {
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 1),
  );
  expect(bytes, isNotNull);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
  expect(image, isNotNull);
}
