import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/repositories/coach_intro_store.dart';
import 'package:ayg/screens/coach/cook_coach_screen.dart';
import 'package:ayg/screens/coach/daily_coach_screen.dart';
import 'package:ayg/services/cook_coach_client.dart';
import 'package:ayg/services/cook_coach_target.dart';
import 'package:ayg/services/daily_coach.dart';
import 'package:ayg/services/daily_coach_session.dart';
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

  const target = CookCoachMealTarget(
    slot: MealSlot.dinner,
    kcal: 650,
    proteinG: 40,
    fatG: 20,
    carbG: 75,
    remainingKcal: 650,
    remainingProteinG: 40,
    remainingFatG: 20,
    remainingCarbG: 75,
  );

  testWidgets('realistic dinner plans at 1179 by 2556', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
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
            target: target,
            client: CookCoachClient(invoke: (_) async => _payload()),
            onRegister: (dish, slot) async {
              expect(slot, MealSlot.dinner);
              expect(dish.kcal, 652);
              expect(
                dish.ingredients.fold<int>(0, (sum, item) => sum + item.kcal),
                dish.kcal,
              );
              expect(dish.gapKcal, -2);
              expect(dish.withinTolerance, isTrue);
              expect(dish.ingredients.first.grams, 60);
              expect(dish.ingredients.first.kcal, 65);
              return const ['entry-1'];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final name in const ['鶏むね肉', '玉ねぎ', 'キャベツ', '卵', 'ごはん']) {
      await tester.tap(find.byKey(Key('cook_choice_$name')));
      await tester.pumpAndSettle();
    }
    _jump(tester, 0);
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/cook_input.png'));

    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();
    expect(find.text('目標の範囲に入っています'), findsNWidgets(2));
    expect(find.text('目標より2kcal多い'), findsNWidgets(2));
    expect(find.text('652kcal　P 39.7g　F 20.2g　C 75.1g'), findsOneWidget);
    expect(find.text('652kcal　P 39.7g　F 20.2g　C 74.6g'), findsOneWidget);
    expect(find.text('鶏むね肉 60g　65kcal　成分表'), findsOneWidget);
    expect(find.text('卵 3個（150g）　227kcal　成分表'), findsOneWidget);
    expect(find.text('塩 1g　0kcal　AIの目安'), findsNWidgets(2));
    expect(find.text('鶏むね肉と玉ねぎの炒め丼'), findsOneWidget);
    expect(find.text('鶏むね肉と玉ねぎの煮'), findsOneWidget);
    expect(
      find.text('1. 鶏むね肉60gを一口大に切る。卵3個（150g）を溶いておく。玉ねぎ177gを食べやすく切る。キャベツ107gを食べやすく切る'),
      findsOneWidget,
    );

    _jump(tester, 0);
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/cook_results.png'));

    await _scrollTextTo(tester, '鶏むね肉と玉ねぎの炒め丼', 96);
    await _write(tester, boundary, File('${directory.path}/cook_recipe.png'));

    await _scrollTextTo(tester, '鶏むね肉と玉ねぎの煮', 96);
    await _write(tester, boundary, File('${directory.path}/cook_results_b.png'));
    expect(
      tester.getRect(find.text('鶏むね肉と玉ねぎの煮')).top,
      greaterThanOrEqualTo(0),
    );
    expect(
      tester.getRect(find.textContaining('鍋を中火にし、サラダ油8gを熱し')).top,
      greaterThanOrEqualTo(0),
    );

    await tester.ensureVisible(find.byKey(const Key('cook_register_on_hand')));
    await tester.tap(find.byKey(const Key('cook_register_on_hand')));
    await tester.pumpAndSettle();
    expect(find.text('食事に追加しました'), findsOneWidget);
    expect(find.text('652kcal　P 39.7g　F 20.2g　C 75.1g'), findsOneWidget);
    expect(find.text('卵 3個（150g）　227kcal'), findsOneWidget);
    _jump(tester, 0);
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/cook_saved.png'));
  });

  testWidgets('over-target day shows an exercise suggestion', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
    directory.createSync(recursive: true);
    final boundary = GlobalKey();
    final now = DateTime(2026, 10, 8, 18);
    final proposal = buildCoachExerciseProposal(
      overageKcal: 280,
      weightKg: 60,
      exercises: const [],
      now: now,
    );
    expect(proposal, isNotNull);
    expect(proposal!.message.contains('速歩き'), isTrue);
    expect(proposal.canRegister, isTrue);

    tester.view.devicePixelRatio = 3;
    await tester.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: RepaintBoundary(
          key: boundary,
          child: DailyCoachScreen(
            introStore: _SeenIntro(),
            now: now,
            load: () async => DailyCoachLoadResult(
              status: DailyCoachStatus.ready,
              focus: DailyCoachFocus.exercise,
              exercise: proposal,
            ),
            onSelectExercise: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('速歩き'), findsOneWidget);
    expect(find.text('この量で登録'), findsOneWidget);
    expect(find.text('自炊コーチ (β)'), findsOneWidget);
    await _write(tester, boundary, File('${directory.path}/coach_over_target.png'));
  });
}

void _jump(WidgetTester tester, double offset) {
  tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(offset);
}

Future<void> _scrollTextTo(WidgetTester tester, String text, double top) async {
  final dy = tester.getTopLeft(find.text(text)).dy;
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final next = (scroll.position.pixels + dy - top).clamp(
    0.0,
    scroll.position.maxScrollExtent,
  );
  scroll.position.jumpTo(next);
  await tester.pumpAndSettle();
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

class _SeenIntro implements CoachIntroStore {
  @override
  Future<bool> hasSeen() async => true;

  @override
  Future<void> markSeen() async {}
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
  return {
    'ok': true,
    'retried': false,
    'calls': [
      {'input_tokens': 400, 'output_tokens': 180, 'latency_ms': 280},
    ],
    'patterns': [
      {
        'kind': 'on_hand',
        'name': '鶏むね肉と玉ねぎの炒め丼',
        'steps': [
          '鶏むね肉60gを一口大に切る。卵3個（150g）を溶いておく。玉ねぎ177gを食べやすく切る。キャベツ107gを食べやすく切る',
          'フライパンを中火にし、サラダ油3gを熱し、鶏むね肉を3分ずつ焼く',
          '玉ねぎとキャベツを加えて2分炒め、塩1gを絡めて1分火を通す。溶いた卵を回し入れて1分火を通す',
          '夕食として、ごはん144gを盛ってのせる',
        ],
        'extras': <String>[],
        'kcal': 652,
        'protein_g': 39.7,
        'fat_g': 20.2,
        'carb_g': 75.1,
        'gap_kcal': -2,
        'gap_protein_g': 0.3,
        'gap_fat_g': -0.2,
        'gap_carb_g': -0.1,
        'within_tolerance': true,
        'ingredients': [
          _row(name: '鶏むね肉', grams: 60, kcal: 65, protein: 14.4, fat: 0.9, carb: 0, code: '1'),
          _row(name: '玉ねぎ', grams: 177, kcal: 65, protein: 1.8, fat: 0.2, carb: 15.6, code: '6'),
          _row(name: 'キャベツ', grams: 107, kcal: 25, protein: 1.4, fat: 0.2, carb: 5.6, code: '8'),
          _row(name: '卵', grams: 150, kcal: 227, protein: 18.5, fat: 15.5, carb: 0.5, code: '4'),
          _row(name: 'ごはん', grams: 144, kcal: 242, protein: 3.6, fat: 0.4, carb: 53.4, code: '2'),
          _row(name: 'サラダ油', grams: 3, kcal: 28, protein: 0, fat: 3, carb: 0, code: '3'),
          _row(name: '塩', grams: 1, kcal: 0, protein: 0, fat: 0, carb: 0),
        ],
      },
      {
        'kind': 'extra',
        'name': '鶏むね肉と玉ねぎの煮',
        'steps': [
          '鶏むね肉90gを一口大に切る。卵2個（100g）を溶いておく。玉ねぎ94gを食べやすく切る。じゃがいも99gを食べやすく切る',
          '鍋を中火にし、サラダ油8gを熱し、鶏むね肉を4分加熱する',
          '玉ねぎとじゃがいもを加え、塩1gを入れて4分煮る。溶いた卵を回し入れて1分火を通す',
          '夕食として、ごはん131gを盛ってのせる',
        ],
        'extras': ['じゃがいも'],
        'kcal': 652,
        'protein_g': 39.7,
        'fat_g': 20.2,
        'carb_g': 74.6,
        'gap_kcal': -2,
        'gap_protein_g': 0.3,
        'gap_fat_g': -0.2,
        'gap_carb_g': 0.4,
        'within_tolerance': true,
        'ingredients': [
          _row(name: '鶏むね肉', grams: 90, kcal: 97, protein: 21.6, fat: 1.3, carb: 0, code: '1'),
          _row(name: '卵', grams: 100, kcal: 151, protein: 12.3, fat: 10.3, carb: 0.3, code: '4'),
          _row(name: 'ごはん', grams: 131, kcal: 220, protein: 3.3, fat: 0.4, carb: 48.6, code: '2'),
          _row(name: '玉ねぎ', grams: 94, kcal: 35, protein: 0.9, fat: 0.1, carb: 8.3, code: '6'),
          _row(name: 'じゃがいも', grams: 99, kcal: 75, protein: 1.6, fat: 0.1, carb: 17.4, code: '7', extra: true),
          _row(name: 'サラダ油', grams: 8, kcal: 74, protein: 0, fat: 8, carb: 0, code: '3'),
          _row(name: '塩', grams: 1, kcal: 0, protein: 0, fat: 0, carb: 0),
        ],
      },
    ],
  };
}
