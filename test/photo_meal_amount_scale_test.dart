import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/screens/food/ai_food_lookup_screen.dart';
import 'package:ayg/screens/food/photo_meal_confirm_screen.dart';
import 'package:ayg/services/ai_food_lookup.dart';
import 'package:ayg/services/photo_meal.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_health_repository.dart';

const _candidate = AiFoodCandidate(
  name: 'サラダチキン',
  amount: '200g',
  kcal: 240,
  proteinG: 48,
  fatG: 4,
  carbG: 2,
  knownProduct: true,
);

String _textOf(WidgetTester tester, String key) {
  return tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
}

Map<String, String> _shown(WidgetTester tester) => {
  'kcal': _textOf(tester, 'photo-meal-kcal'),
  'protein': _textOf(tester, 'photo-meal-protein'),
  'fat': _textOf(tester, 'photo-meal-fat'),
  'carb': _textOf(tester, 'photo-meal-carb'),
};

String _storeAsTimestamptz(String sent) {
  final hasOffset = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(sent);
  final utc = DateTime.parse(hasOffset ? sent : '${sent}Z').toUtc();
  return '${utc.toIso8601String().substring(0, 19)}+00:00';
}

Future<AppController> _open(
  WidgetTester tester, {
  PhotoMealEstimate? estimate,
  DateTime? loggedAt,
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 1400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final controller = AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: PhotoMealConfirmScreen(
        controller: controller,
        loggedAt: loggedAt ?? DateTime(2026, 10, 9, 12, 30),
        hadUserDishName: true,
        title: aiFoodLookupEstimateTitle,
        subtitle: aiFoodLookupEstimateSubtitle,
        analysis: PhotoMealAnalysis(
          usageId: null,
          estimate: estimate ?? _candidate.toEstimate(),
        ),
        recordEdit: (_, _) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  group('leadingPhotoAmountNumber', () {
    test('reads the leading number of an amount', () {
      expect(leadingPhotoAmountNumber('200g'), 200);
      expect(leadingPhotoAmountNumber('200 g'), 200);
      expect(leadingPhotoAmountNumber('1.5杯'), 1.5);
      expect(leadingPhotoAmountNumber('2個'), 2);
      expect(leadingPhotoAmountNumber('１５０ｇ'), 150);
      expect(leadingPhotoAmountNumber('約300g'), 300);
      expect(leadingPhotoAmountNumber('1/2個'), 0.5);
      expect(leadingPhotoAmountNumber('一人前'), isNull);
      expect(leadingPhotoAmountNumber(''), isNull);
      expect(leadingPhotoAmountNumber('0g'), isNull);
    });

    test('scales all four from the original estimate', () {
      final scaled = scalePhotoMealEstimate(_candidate.toEstimate(), '300g')!;
      expect(scaled.kcal, 360);
      expect(scaled.proteinG, 72);
      expect(scaled.fatG, 6);
      expect(scaled.carbG, 3);
      expect(scalePhotoMealEstimate(_candidate.toEstimate(), '少し'), isNull);
    });
  });

  testWidgets('200g -> 400g doubles kcal and PFC, and shows the hint', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text(photoMealAmountScaleHint), findsOneWidget);
    expect(_shown(tester), {
      'kcal': '240',
      'protein': '48',
      'fat': '4',
      'carb': '2',
    });
    await tester.enterText(find.byKey(const Key('photo-meal-amount')), '400g');
    await tester.pump();
    expect(_shown(tester), {
      'kcal': '480',
      'protein': '96',
      'fat': '8',
      'carb': '4',
    });
  });

  testWidgets('200g -> 100g halves kcal and PFC', (tester) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('photo-meal-amount')), '100g');
    await tester.pump();
    expect(_shown(tester), {
      'kcal': '120',
      'protein': '24',
      'fat': '2',
      'carb': '1',
    });
  });

  testWidgets('a hand-edited kcal is recomputed from the original estimate', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('photo-meal-kcal')), '999');
    await tester.pump();
    expect(_textOf(tester, 'photo-meal-kcal'), '999');
    await tester.enterText(find.byKey(const Key('photo-meal-amount')), '300g');
    await tester.pump();
    expect(_shown(tester), {
      'kcal': '360',
      'protein': '72',
      'fat': '6',
      'carb': '3',
    });
  });

  testWidgets('same number with a new unit does not rescale or reset edits', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('photo-meal-kcal')), '250');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('photo-meal-amount')), '200 g');
    await tester.pump();
    expect(_textOf(tester, 'photo-meal-kcal'), '250');
  });

  testWidgets('an unparseable amount leaves the values untouched', (
    tester,
  ) async {
    await _open(tester);
    await tester.enterText(find.byKey(const Key('photo-meal-amount')), '少し');
    await tester.pump();
    expect(_shown(tester), {
      'kcal': '240',
      'protein': '48',
      'fat': '4',
      'carb': '2',
    });
    await tester.enterText(find.byKey(const Key('photo-meal-amount')), '');
    await tester.pump();
    expect(_textOf(tester, 'photo-meal-kcal'), '240');
  });

  testWidgets('an estimate without a number in its amount never rescales', (
    tester,
  ) async {
    await _open(
      tester,
      estimate: const PhotoMealEstimate(
        dishName: '定食',
        amount: '一人前',
        kcal: 700,
        proteinG: 30,
        fatG: 20,
        carbG: 100,
        confidence: 0.6,
        items: [],
      ),
    );
    expect(find.text(photoMealAmountScaleHint), findsNothing);
    await tester.enterText(find.byKey(const Key('photo-meal-amount')), '2人前');
    await tester.pump();
    expect(_textOf(tester, 'photo-meal-kcal'), '700');
  });

  testWidgets(
    'saved entry equals the shown values, on the day total, after an edit, '
    'and through the server row round-trip',
    (tester) async {
      final now = DateTime.now();
      final loggedAt = DateTime(now.year, now.month, now.day, 12, 30);
      final controller = await _open(tester, loggedAt: loggedAt);
      controller.setProfile(
        UserProfile(
          birthDate: DateTime(1990, 1, 1),
          gender: Gender.male,
          heightCm: 175,
          weightKg: 75,
        ),
      );
      controller.setNutritionSettings(
        const NutritionSettings(
          useHealthIntegration: false,
          activityLevel: ActivityLevel.moderate,
        ),
      );
      controller.setGoal(
        Goal(
          type: GoalType.maintain,
          targetWeightKg: 75,
          targetDate: loggedAt.add(const Duration(days: 90)),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('photo-meal-amount')),
        '250g',
      );
      await tester.pump();
      final shown = _shown(tester);
      expect(shown, {
        'kcal': '300',
        'protein': '60',
        'fat': '5',
        'carb': '2.5',
      });
      await tester.tap(find.text('この内容で登録'));
      await tester.pumpAndSettle();

      final entry = controller.foodEntries.single;
      expect(entry.totalKcal, 300);
      expect(entry.totalProteinG, 60);
      expect(entry.totalFatG, 5);
      expect(entry.totalCarbG, 2.5);
      expect(entry.unitType, FoodUnitType.g);
      expect(entry.consumedAmount, 250);
      expect(entry.baseAmount, 250);
      expect(entry.loggedAt, loggedAt);

      // ホームの今日の合計にも同じ値が出る。
      expect(controller.summary!.intakeKcal, 300);
      expect(controller.summary!.intakeProteinG, 60);

      // あとで名前だけ直しても、数値は変わらない。
      await controller.updateFood(entry.copyWith(name: 'サラダチキン（直した）'));
      final edited = controller.foodEntries.single;
      expect(edited.name, 'サラダチキン（直した）');
      expect(edited.totalKcal, 300);
      expect(edited.totalProteinG, 60);
      expect(edited.totalFatG, 5);
      expect(edited.totalCarbG, 2.5);
      expect(controller.summary!.intakeKcal, 300);

      // 端末→サーバ→端末の往復で、日時・内容・件数が変わらない。
      final row = FoodMasterRowMapper.foodEntryToRow(edited, userId: 'u1');
      final stored = Map<String, dynamic>.from(row)
        ..['logged_at'] = _storeAsTimestamptz(row['logged_at'] as String);
      final back = FoodMasterRowMapper.foodEntryFromRow(stored);
      expect(back.id, edited.id);
      expect(back.name, edited.name);
      expect(back.loggedAt.year, loggedAt.year);
      expect(back.loggedAt.month, loggedAt.month);
      expect(back.loggedAt.day, loggedAt.day);
      expect(back.loggedAt.hour, 12);
      expect(back.loggedAt.minute, 30);
      expect(back.totalKcal, closeTo(300, 1e-9));
      expect(back.totalProteinG, closeTo(60, 1e-9));
      expect(back.totalFatG, closeTo(5, 1e-9));
      expect(back.totalCarbG, closeTo(2.5, 1e-9));
      expect(controller.foodEntries, hasLength(1));
    },
  );

  test('foodEntryFromPhotoMeal keeps totals for non-gram amounts', () {
    final entry = foodEntryFromPhotoMeal(
      id: 'x',
      name: '牛丼',
      amountText: '1.5杯',
      kcal: 855,
      proteinG: 33,
      fatG: 27,
      carbG: 120,
      loggedAt: DateTime(2026, 10, 9, 12),
    );
    expect(entry.totalKcal, 855);
    expect(entry.totalProteinG, 33);
    expect(entry.totalFatG, 27);
    expect(entry.totalCarbG, 120);
  });
}
