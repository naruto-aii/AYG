import 'dart:io';
import 'dart:typed_data';

import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/repositories/pending_record_store.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/screens/food/photo_meal_confirm_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Analytics.onEmitForTest = null;
  });

  group('parsePhotoMealEstimate', () {
    Map<String, Object?> valid() {
      return {
        'dish_name': 'カレー',
        'amount': '200g',
        'kcal': 400,
        'protein_g': 15,
        'fat_g': 12,
        'carb_g': 50,
        'confidence': 0.7,
        'items': <Object?>[],
      };
    }

    test('accepts a total whose PFC is within tolerance', () {
      final parsed = parsePhotoMealEstimate(valid());
      expect(parsed, isNotNull);
      expect(parsed!.dishName, 'カレー');
      expect(parsed.kcal, 400);
    });

    test('rejects negative, absurd, and PFC-inconsistent values', () {
      expect(parsePhotoMealEstimate({...valid(), 'kcal': -1}), isNull);
      expect(parsePhotoMealEstimate({...valid(), 'kcal': 10001}), isNull);
      expect(parsePhotoMealEstimate({...valid(), 'protein_g': 1001}), isNull);
      expect(parsePhotoMealEstimate({...valid(), 'confidence': 1.2}), isNull);
      expect(
        parsePhotoMealEstimate({
          ...valid(),
          'kcal': 800,
          'protein_g': 0,
          'fat_g': 0,
          'carb_g': 0,
        }),
        isNull,
      );
      expect(
        parsePhotoMealEstimate({
          ...valid(),
          'items': [
            {
              'name': 'ご飯',
              'amount': '150g',
              'kcal': 500,
              'protein_g': 0,
              'fat_g': 0,
              'carb_g': 0,
            },
          ],
        }),
        isNull,
      );
    });
  });

  test('compressMealPhoto keeps the long edge at or under 1024 JPEG', () {
    final source = img.Image(width: 2000, height: 800);
    img.fill(source, color: img.ColorRgb8(20, 120, 40));
    final jpeg = compressMealPhoto(Uint8List.fromList(img.encodeJpg(source)));
    expect(jpeg[0], 0xFF);
    expect(jpeg[1], 0xD8);
    expect(jpeg[2], 0xFF);
    final decoded = img.decodeJpg(jpeg);
    expect(decoded, isNotNull);
    final longest = decoded!.width > decoded.height
        ? decoded.width
        : decoded.height;
    expect(longest, lessThanOrEqualTo(photoMealLongEdge));
  });

  test('save writes exactly one outbox row and one food_entry_added', () async {
    final pending = PendingRecordStore();
    final controller = AppController(pendingRecords: pending);
    addTearDown(controller.dispose);
    final events = <Map<String, Object?>>[];
    Analytics.onEmitForTest = (name, props) {
      if (name == 'food_entry_added') {
        events.add(props);
      }
    };

    final loggedAt = DateTime(2026, 10, 8, 12, 30);
    final entry = await saveConfirmedPhotoMeal(
      controller: controller,
      loggedAt: loggedAt,
      name: '親子丼',
      amountText: '1杯',
      kcal: 700,
      proteinG: 30,
      fatG: 25,
      carbG: 80,
    );

    expect(controller.foodEntries, hasLength(1));
    expect(controller.foodEntries.single.id, entry.id);
    expect(controller.foodEntries.single.name, '親子丼');
    expect(entry.loggedAt, loggedAt);
    expect(entry.sourceType, FoodEntrySource.manual);
    expect(entry.unitType, FoodUnitType.serving);
    expect(entry.baseAmount, entry.consumedAmount);
    expect(await pending.preferLocalIds(PendingRecordKind.food), {entry.id});
    expect(await pending.pendingDeleteIds(PendingRecordKind.food), isEmpty);
    expect(events, hasLength(1));
    expect(events.single['method'], 'manual');
    expect(events.single['items_count'], 1);
  });

  test('a gram amount is stored once, not scaled', () {
    final entry = foodEntryFromPhotoMeal(
      id: 'food-1',
      name: 'サラダ',
      amountText: '200g',
      kcal: 80,
      proteinG: 3,
      fatG: 4,
      carbG: 6,
      loggedAt: DateTime(2026, 10, 8, 18),
    );
    expect(entry.unitType, FoodUnitType.g);
    expect(entry.baseAmount, 200);
    expect(entry.consumedAmount, 200);
    expect(entry.kcalPerBase, 80);
  });

  testWidgets('a missing dish name does not write until it is confirmed', (
    tester,
  ) async {
    final harness = await _openConfirm(tester, hadUserDishName: false);
    addTearDown(harness.controller.dispose);

    await tester.tap(find.text('この内容で登録'));
    await tester.pumpAndSettle();
    expect(find.text('料理名を確認してください'), findsOneWidget);
    expect(harness.controller.foodEntries, isEmpty);
    expect(harness.edits, isEmpty);

    await tester.enterText(
      find.byKey(const ValueKey('photo_meal_name_confirm')),
      '',
    );
    await tester.tap(find.text('この名前で登録'));
    await tester.pumpAndSettle();
    expect(find.text('料理名を入力してください'), findsOneWidget);
    expect(harness.controller.foodEntries, isEmpty);

    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(harness.controller.foodEntries, isEmpty);
    expect(
      await harness.pending.preferLocalIds(PendingRecordKind.food),
      isEmpty,
    );

    await tester.tap(find.text('この内容で登録'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('photo_meal_name_confirm')),
      '親子丼',
    );
    await tester.tap(find.text('この名前で登録'));
    await tester.pumpAndSettle();

    expect(harness.controller.foodEntries, hasLength(1));
    expect(harness.controller.foodEntries.single.name, '親子丼');
    expect(await harness.pending.preferLocalIds(PendingRecordKind.food), {
      harness.controller.foodEntries.single.id,
    });
    expect(harness.events, ['manual']);
    expect(harness.edits, [true]);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('an entered dish name saves one record without the dialog', (
    tester,
  ) async {
    final harness = await _openConfirm(tester, hadUserDishName: true);
    addTearDown(harness.controller.dispose);

    await tester.tap(find.text('この内容で登録'));
    await tester.pumpAndSettle();

    expect(find.text('料理名を確認してください'), findsNothing);
    expect(harness.controller.foodEntries, hasLength(1));
    expect(harness.controller.foodEntries.single.name, 'カレー');
    expect(harness.events, ['manual']);
    expect(harness.edits, [false]);
    expect(
      await harness.pending.preferLocalIds(PendingRecordKind.food),
      hasLength(1),
    );
  });

  testWidgets('an absurd calorie does not write a meal', (tester) async {
    final harness = await _openConfirm(tester, hadUserDishName: true);
    addTearDown(harness.controller.dispose);

    final kcal = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.controller?.text == '400',
    );
    await tester.enterText(kcal, '20000');
    await tester.tap(find.text('この内容で登録'));
    await tester.pumpAndSettle();

    expect(find.text('カロリーとPFCは、0以上の範囲で入れてください'), findsOneWidget);
    expect(harness.controller.foodEntries, isEmpty);
    expect(harness.events, isEmpty);
    expect(
      await harness.pending.preferLocalIds(PendingRecordKind.food),
      isEmpty,
    );
  });

  testWidgets('the meal form shows 写真で登録 on a phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: FoodFormScreen(
          controller: controller,
          openFoodFactsService: OpenFoodFactsService(
            userAgent: 'AYG/test (test@example.com)',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('写真で登録'), findsOneWidget);
    expect(find.text('検索'), findsOneWidget);
    expect(find.text('その他'), findsOneWidget);
    expect(find.text('手入力'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('note chips append without passing 100 characters or repeating', () {
    expect(appendPhotoMealNote('', '油多め'), '油多め');
    expect(appendPhotoMealNote('油多め', '皮なし'), '油多め、皮なし');
    expect(appendPhotoMealNote('油多め、皮なし', '油多め'), '油多め、皮なし');
    final full = 'あ' * photoMealNoteMaxLength;
    expect(appendPhotoMealNote(full, '揚げ物'), full);
    expect(photoMealNoteChips, contains('タレ・ソース多め'));
  });

  test('analyze sends a clipped note and does not require one', () async {
    final sent = <Map<String, Object?>>[];
    final client = PhotoMealClient(
      invoke: (body) async {
        sent.add(body);
        return {
          'ok': true,
          'usage_id': 'usage-1',
          'estimate': {
            'dish_name': 'カレー',
            'amount': '200g',
            'kcal': 400,
            'protein_g': 15,
            'fat_g': 12,
            'carb_g': 50,
            'confidence': 0.7,
            'items': <Object?>[],
          },
        };
      },
    );
    await client.analyze(
      jpeg: Uint8List.fromList([1, 2, 3]),
      dishName: ' カレー ',
      amount: '200g',
      note: ' 油多め ',
    );
    expect(sent.single['note'], '油多め');
    expect(sent.single['dish_name'], 'カレー');
    await client.analyze(
      jpeg: Uint8List.fromList([1]),
      dishName: '',
      amount: '',
      note: 'あ' * 120,
    );
    expect((sent.last['note'] as String).length, photoMealNoteMaxLength);
  });

  test('migration does not store the photo and locks edits to one column', () {
    final sql = File(
      'supabase/migrations/20261008140000_meal_photo_analyses.sql',
    ).readAsStringSync();
    expect(sql, contains('enable row level security'));
    expect(sql, contains("'photo_meal'"));
    expect(sql, contains('only user_edited can change'));
    expect(sql, isNot(contains('image_base64')));
    expect(sql, contains('had_note boolean not null'));
    expect(sql, isNot(contains('note text')));
    final rollback = File(
      'supabase/rollback/20261008140000_meal_photo_analyses_down.sql',
    ).readAsStringSync();
    final deleteAt = rollback.indexOf("feature = 'photo_meal'");
    final recheckAt = rollback.indexOf("'coach'");
    expect(deleteAt, greaterThan(0));
    expect(recheckAt, greaterThan(deleteAt));
  });
}

class _ConfirmHarness {
  _ConfirmHarness({
    required this.controller,
    required this.pending,
    required this.events,
    required this.edits,
  });

  final AppController controller;
  final PendingRecordStore pending;
  final List<String> events;
  final List<bool> edits;
}

Future<_ConfirmHarness> _openConfirm(
  WidgetTester tester, {
  required bool hadUserDishName,
}) async {
  final pending = PendingRecordStore();
  final controller = AppController(pendingRecords: pending);
  final events = <String>[];
  final edits = <bool>[];
  Analytics.onEmitForTest = (name, props) {
    if (name == 'food_entry_added') {
      events.add(props['method']! as String);
    }
  };
  final screen = PhotoMealConfirmScreen(
    controller: controller,
    loggedAt: DateTime(2026, 10, 8, 19),
    hadUserDishName: hadUserDishName,
    analysis: const PhotoMealAnalysis(
      usageId: 'usage-1',
      estimate: PhotoMealEstimate(
        dishName: 'カレー',
        amount: '200g',
        kcal: 400,
        proteinG: 15,
        fatG: 12,
        carbG: 50,
        confidence: 0.7,
        items: [
          PhotoMealItemEstimate(
            name: 'ご飯',
            amount: '150g',
            kcal: 250,
            proteinG: 4,
            fatG: 1,
            carbG: 55,
          ),
          PhotoMealItemEstimate(
            name: 'ルー',
            amount: '100g',
            kcal: 150,
            proteinG: 11,
            fatG: 11,
            carbG: 0,
          ),
        ],
      ),
    ),
    recordEdit: (usageId, edited) async {
      expect(usageId, 'usage-1');
      edits.add(edited);
    },
  );

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) {
          return TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  settings: const RouteSettings(name: 'photo_meal_confirm'),
                  builder: (context) => screen,
                ),
              );
            },
            child: const Text('open'),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.text('これはAIの推定です。登録の前に確認して、数値を直せます。'), findsOneWidget);
  expect(find.text('合計を1件として記録します。'), findsOneWidget);

  return _ConfirmHarness(
    controller: controller,
    pending: pending,
    events: events,
    edits: edits,
  );
}
