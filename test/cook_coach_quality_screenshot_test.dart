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
    proteinG: 32,
    fatG: 18,
    carbG: 75,
    remainingKcal: 650,
    remainingProteinG: 32,
    remainingFatG: 18,
    remainingCarbG: 75,
  );

  testWidgets('realistic dinner plans at 1290 by 2796', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
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
            target: target,
            client: CookCoachClient(invoke: (_) async => _payload()),
            onRegister: (dish, slot) async {
              expect(slot, MealSlot.dinner);
              expect(dish.kcal, 604);
              expect(
                dish.ingredients.fold<int>(0, (sum, item) => sum + item.kcal),
                dish.kcal,
              );
              expect(dish.gapKcal, 46);
              expect(dish.withinTolerance, isFalse);
              expect(dish.ingredients.first.grams, 140);
              expect(dish.ingredients.first.kcal, 151);
              return const ['entry-1'];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final name in const ['鶏むね肉', 'ごはん']) {
      await tester.tap(find.byKey(Key('cook_choice_$name')));
      await tester.pumpAndSettle();
    }
    _jump(tester, 0);
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/cook_input.png'));

    await tester.ensureVisible(find.byKey(const Key('cook_generate')));
    await tester.tap(find.byKey(const Key('cook_generate')));
    await tester.pumpAndSettle();
    expect(find.text('目標の範囲に入っています'), findsNothing);
    expect(find.text('手持ちだけで作れます'), findsOneWidget);
    expect(find.text('買い足しで作れます'), findsOneWidget);
    expect(find.text('鶏むね肉の照り焼き、ごはんの温め'), findsOneWidget);
    expect(find.text('油淋鶏、ごはんの温め'), findsOneWidget);
    expect(find.text('604kcal　P 38.7g　F 10.7g　C 88.1g'), findsOneWidget);
    expect(find.text('604kcal　P 41.0g　F 12.9g　C 82.5g'), findsOneWidget);
    expect(find.text('目標まであと 46kcal'), findsNWidgets(2));
    expect(find.textContaining('P 6.7g 多い'), findsOneWidget);
    expect(find.textContaining('F あと 7.3g'), findsOneWidget);
    expect(find.textContaining('C 13.1g 多い'), findsOneWidget);
    expect(find.text('1. 鶏むね肉を一口大に切る。'), findsOneWidget);
    expect(find.text('5. ごはん207gを茶碗によそう（冷やご飯なら電子レンジで温める）。'), findsOneWidget);
    expect(find.text('調理の目安 10分'), findsOneWidget);
    expect(find.text('調理の目安 8分'), findsOneWidget);
    expect(find.textContaining('サラダ油（家にあるもの）'), findsWidgets);
    expect(find.text('ねぎ（買い足し）'), findsOneWidget);
    expect(find.text('買い足すもの: ねぎ'), findsOneWidget);
    expect(find.textContaining('成分表'), findsNothing);

    _jump(tester, 0);
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/cook_results.png'));

    await _scrollTextTo(tester, '油淋鶏、ごはんの温め', 80);
    await _write(tester, boundary, File('${directory.path}/cook_results_extra.png'));
    expect(
      tester.getRect(find.text('油淋鶏、ごはんの温め')).top,
      greaterThanOrEqualTo(0),
    );

    await tester.ensureVisible(find.byKey(const Key('cook_register_on_hand')));
    await tester.tap(find.byKey(const Key('cook_register_on_hand')));
    await tester.pumpAndSettle();
    expect(find.text('食事に追加しました'), findsOneWidget);
    expect(find.text('604kcal　P 38.7g　F 10.7g　C 88.1g'), findsOneWidget);
    expect(find.text('鶏むね肉 140g　151kcal'), findsOneWidget);
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
    await tester.binding.setSurfaceSize(const Size(430, 932));
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
  // DesignScreen は幅 390 を画面幅へ拡大する。スクロール量は設計座標。
  const scale = 430 / 390;
  final dy = tester.getTopLeft(find.text(text)).dy;
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  final next = (scroll.position.pixels + (dy - top) / scale).clamp(
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
  expect(image!.width, 1290);
  expect(image.height, 2796);
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
  // 鶏むね肉＋ごはん、夕食 650/32/18/75。selectCookPlans の実測。行の和が画面の合計。
  return {
    'ok': true,
    'retried': false,
    'calls': const <Map<String, Object?>>[],
    'patterns': [
      {
        'kind': 'on_hand',
        'name': '鶏むね肉の照り焼き、ごはんの温め',
        'minutes': 10,
        'steps': [
          '鶏むね肉を一口大に切る。',
          'フライパンを中火にし、サラダ油8gを熱して鶏むね肉を5分焼く。',
          'しょうゆ12gとみりん10gと砂糖6gを加えて3分絡め、照りを出す。',
          '火を止めて器に盛る。',
          'ごはん207gを茶碗によそう（冷やご飯なら電子レンジで温める）。',
        ],
        'extras': <String>[],
        'kcal': 604,
        'protein_g': 38.7,
        'fat_g': 10.7,
        'carb_g': 88.1,
        'gap_kcal': 46,
        'gap_protein_g': -6.7,
        'gap_fat_g': 7.3,
        'gap_carb_g': -13.1,
        'within_tolerance': false,
        'gap_reason': 'たんぱく質は38.7gで、目標より6.7g多い。脂質は10.7gで、目標より7.3g少ない。炭水化物は88.1gで、目標より13.1g多い。',
        'ingredients': [
          _row(name: '鶏むね肉', grams: 140, kcal: 151, protein: 32.6, fat: 2.1, carb: 0.1, code: '11220'),
          _row(name: 'サラダ油', grams: 8, kcal: 74, protein: 0, fat: 8, carb: 0, code: '14006', assumed: true),
          _row(name: 'しょうゆ', grams: 12, kcal: 9, protein: 0.9, fat: 0, carb: 0.9, code: '17007', assumed: true),
          _row(name: 'みりん', grams: 10, kcal: 24, protein: 0, fat: 0, carb: 4.3, code: '16025', assumed: true),
          _row(name: '砂糖', grams: 6, kcal: 23, protein: 0, fat: 0, carb: 6, code: '03003', assumed: true),
          _row(name: 'ごはん', grams: 207, kcal: 323, protein: 5.2, fat: 0.6, carb: 76.8, code: '01088'),
        ],
      },
      {
        'kind': 'extra',
        'name': '油淋鶏、ごはんの温め',
        'minutes': 8,
        'steps': [
          '鶏むね肉とねぎを食べやすく切る。',
          'フライパンを中火にし、サラダ油10gを熱して鶏むね肉を6分焼く。',
          '酢14gとしょうゆ8gと砂糖8gと水を30mlとねぎを煮立たせてたれにする。',
          '焼いた鶏むね肉にたれをかけて器に盛る。',
          'ごはん191gを茶碗によそう（冷やご飯なら電子レンジで温める）。',
        ],
        'extras': ['ねぎ'],
        'kcal': 604,
        'protein_g': 41,
        'fat_g': 12.9,
        'carb_g': 82.5,
        'gap_kcal': 46,
        'gap_protein_g': -9,
        'gap_fat_g': 5.1,
        'gap_carb_g': -7.5,
        'within_tolerance': false,
        'gap_reason': 'たんぱく質は41gで、目標より9g多い。脂質は12.9gで、目標より5.1g少ない。油は10gまで。',
        'ingredients': [
          _row(name: '鶏むね肉', grams: 150, kcal: 162, protein: 35, fat: 2.3, carb: 0.2, code: '11220'),
          _row(name: 'ねぎ', grams: 40, kcal: 11, protein: 0.6, fat: 0, carb: 2.5, code: '06226', extra: true),
          _row(name: 'サラダ油', grams: 10, kcal: 92, protein: 0, fat: 10, carb: 0, code: '14006', assumed: true),
          _row(name: '酢', grams: 14, kcal: 4, protein: 0, fat: 0, carb: 0.3, code: '17015', assumed: true),
          _row(name: 'しょうゆ', grams: 8, kcal: 6, protein: 0.6, fat: 0, carb: 0.6, code: '17007', assumed: true),
          _row(name: '砂糖', grams: 8, kcal: 31, protein: 0, fat: 0, carb: 8, code: '03003', assumed: true),
          _row(name: 'ごはん', grams: 191, kcal: 298, protein: 4.8, fat: 0.6, carb: 70.9, code: '01088'),
        ],
      },
    ],
  };
}
