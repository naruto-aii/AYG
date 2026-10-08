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
    proteinG: 28,
    fatG: 22,
    carbG: 70,
    remainingKcal: 650,
    remainingProteinG: 28,
    remainingFatG: 22,
    remainingCarbG: 70,
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
              expect(dish.kcal, 640);
              expect(
                dish.ingredients.fold<int>(0, (sum, item) => sum + item.kcal),
                dish.kcal,
              );
              expect(dish.gapKcal, 10);
              expect(dish.withinTolerance, isTrue);
              expect(dish.ingredients.first.grams, 132);
              expect(dish.ingredients.first.kcal, 242);
              return const ['entry-1'];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final name in const ['豚こま切れ', 'ごはん']) {
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
    expect(find.text('手持ちだけで作れます'), findsOneWidget);
    expect(find.text('買い足しで作れます'), findsOneWidget);
    expect(find.text('豚こまの照り焼き丼'), findsOneWidget);
    expect(find.text('豚こまのガーリック丼'), findsOneWidget);
    expect(find.text('640kcal　P 29.3g　F 24.7g　C 72.9g'), findsOneWidget);
    expect(find.text('629kcal　P 29.7g　F 24.2g　C 71.5g'), findsOneWidget);
    expect(find.text('1. 豚こまを一口大に切る。'), findsOneWidget);
    expect(find.textContaining('にんにく23gを添える'), findsOneWidget);
    expect(find.text('調理の目安 5分'), findsNWidgets(2));
    expect(find.textContaining('（家にあるもの）'), findsWidgets);
    expect(find.text('にんにく（買い足し）'), findsOneWidget);
    expect(find.textContaining('成分表'), findsNothing);

    _jump(tester, 0);
    await tester.pumpAndSettle();
    await _write(tester, boundary, File('${directory.path}/cook_results.png'));

    await _scrollTextTo(tester, '豚こまのガーリック丼', 80);
    await _write(tester, boundary, File('${directory.path}/cook_results_extra.png'));
    expect(
      tester.getRect(find.text('豚こまのガーリック丼')).top,
      greaterThanOrEqualTo(0),
    );

    await tester.ensureVisible(find.byKey(const Key('cook_register_on_hand')));
    await tester.tap(find.byKey(const Key('cook_register_on_hand')));
    await tester.pumpAndSettle();
    expect(find.text('食事に追加しました'), findsOneWidget);
    expect(find.text('640kcal　P 29.3g　F 24.7g　C 72.9g'), findsOneWidget);
    expect(find.text('豚こま 132g　242kcal'), findsOneWidget);
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
  return {
    'ok': true,
    'retried': false,
    'calls': const <Map<String, Object?>>[],
    'patterns': [
      {
        'kind': 'on_hand',
        'name': '豚こまの照り焼き丼',
        'minutes': 5,
        'steps': [
          '豚こまを一口大に切る。',
          'フライパンを中火にし、サラダ油9gを熱して豚こまを3分焼く。',
          'しょうゆ11gとみりん11gと砂糖7gを加えて2分絡める。',
          'ごはん162gにのせてすぐに出す。',
        ],
        'extras': <String>[],
        'kcal': 640,
        'protein_g': 29.3,
        'fat_g': 24.7,
        'carb_g': 72.9,
        'gap_kcal': 10,
        'gap_protein_g': -1.3,
        'gap_fat_g': -2.7,
        'gap_carb_g': -2.9,
        'within_tolerance': true,
        'ingredients': [
          _row(name: '豚こま', grams: 132, kcal: 242, protein: 24.4, fat: 15.2, carb: 0.3, code: '11115'),
          _row(name: 'ごはん', grams: 162, kcal: 253, protein: 4.1, fat: 0.5, carb: 60.1, code: '01088'),
          _row(name: 'サラダ油', grams: 9, kcal: 83, protein: 0, fat: 9, carb: 0, code: '14006', assumed: true),
          _row(name: 'しょうゆ', grams: 11, kcal: 8, protein: 0.8, fat: 0, carb: 0.8, code: '17007', assumed: true),
          _row(name: 'みりん', grams: 11, kcal: 27, protein: 0, fat: 0, carb: 4.7, code: '16025', assumed: true),
          _row(name: '砂糖', grams: 7, kcal: 27, protein: 0, fat: 0, carb: 7, code: '03003', assumed: true),
        ],
      },
      {
        'kind': 'extra',
        'name': '豚こまのガーリック丼',
        'minutes': 5,
        'steps': [
          '豚こまを一口大に切る。にんにく23gを添える。',
          'フライパンを中火にし、サラダ油9gを熱して豚こまを3分焼く。',
          'しょうゆ12gとみりん9gを加えて2分絡め、中まで火を通す。',
          'ごはん162gを器に盛り、具をのせる。',
        ],
        'extras': ['にんにく'],
        'kcal': 629,
        'protein_g': 29.7,
        'fat_g': 24.2,
        'carb_g': 71.5,
        'gap_kcal': 21,
        'gap_protein_g': -1.7,
        'gap_fat_g': -2.2,
        'gap_carb_g': -1.5,
        'within_tolerance': true,
        'ingredients': [
          _row(name: '豚こま', grams: 126, kcal: 231, protein: 23.3, fat: 14.5, carb: 0.3, code: '11115'),
          _row(name: 'にんにく', grams: 23, kcal: 31, protein: 1.4, fat: 0.2, carb: 6.3, code: '06223', extra: true),
          _row(name: 'ごはん', grams: 162, kcal: 253, protein: 4.1, fat: 0.5, carb: 60.1, code: '01088'),
          _row(name: 'サラダ油', grams: 9, kcal: 83, protein: 0, fat: 9, carb: 0, code: '14006', assumed: true),
          _row(name: 'しょうゆ', grams: 12, kcal: 9, protein: 0.9, fat: 0, carb: 0.9, code: '17007', assumed: true),
          _row(name: 'みりん', grams: 9, kcal: 22, protein: 0, fat: 0, carb: 3.9, code: '16025', assumed: true),
        ],
      },
    ],
  };
}
