import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/calculation/calorie_target_mode.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/health_characteristics.dart';
import 'package:ayg/screens/onboarding/activity_level_screen.dart';
import 'package:ayg/screens/onboarding/goal_setup_screen.dart';
import 'package:ayg/screens/settings/settings_goal_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/screens/shell/main_shell_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/design/settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

AppController _controller({required bool health, Gender gender = Gender.male}) {
  final controller = AppController(
    healthRepository: MockHealthRepository(isAvailable: true),
    authenticationRepository: MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    ),
    dataSyncRepository: MockDataSyncRepository(),
  );
  controller.setNutritionSettings(
    NutritionSettings(
      useHealthIntegration: health,
      activityLevel: health ? null : ActivityLevel.moderate,
    ),
  );
  controller.setProfile(
    UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: gender,
      heightCm: 175,
      weightKg: 70,
    ),
  );
  return controller;
}

String _text(WidgetTester tester, String key) => tester
    .widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
        matchRoot: true,
      ),
    )
    .controller
    .text;

List<String> _fields(WidgetTester tester) => [
  _text(tester, 'goal-target-kcal'),
  _text(tester, 'goal-target-protein'),
  _text(tester, 'goal-target-fat'),
  _text(tester, 'goal-target-carb'),
];

void _expectAllNumbers(List<String> fields) {
  for (final value in fields) {
    expect(int.tryParse(value), isNotNull, reason: 'fields: $fields');
    expect(int.parse(value), greaterThan(0), reason: 'fields: $fields');
  }
}

Future<void> _setDate(WidgetTester tester, DateTime date) async {
  final current = find.textContaining(RegExp(r'^\d{4}年\d+月\d+日$'));
  await tester.ensureVisible(current.first);
  await tester.tap(current.first);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final localizations = MaterialLocalizations.of(
    tester.element(find.byType(DatePickerDialog)),
  );
  await tester.enterText(
    find.descendant(
      of: find.byType(DatePickerDialog),
      matching: find.byType(TextField),
    ),
    localizations.formatCompactDate(date),
  );
  await tester.tap(find.text(localizations.okButtonLabel));
  await tester.pumpAndSettle();
}

Future<MockHealthRepository> _pumpGoalSetup(
  WidgetTester tester,
  AppController controller,
) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final auth = MockAuthenticationRepository();
  addTearDown(auth.dispose);
  final health = MockHealthRepository(isAvailable: true);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: GoalSetupScreen(
        controller: controller,
        openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
        authenticationRepository: auth,
        healthRepository: health,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return health;
}

void _expectHealthRowOpens(WidgetTester tester, MockHealthRepository health) {
  final shell = tester.widget<MainShellScreen>(
    find.byType(MainShellScreen, skipOffstage: false),
  );
  expect(shell.healthRepository, same(health));
  final settings = tester.widget<SettingsScreen>(
    find.byType(SettingsScreen, skipOffstage: false),
  );
  expect(settings.healthRepository, same(health));
  final row = tester.widget<SettingsRow>(
    find.ancestor(
      of: find.text('活動・Health', skipOffstage: false),
      matching: find.byType(SettingsRow, skipOffstage: false),
    ),
  );
  expect(row.onTap, isNotNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final today = DateTime.now();
  final targetDate = DateTime(today.year, today.month, today.day + 97);

  group('Health の受け渡し', () {
    testWidgets('Health 連携ありで目標設定を終えると、設定の「活動・Health」が開ける', (tester) async {
      final controller = _controller(health: true);
      addTearDown(controller.dispose);
      final health = await _pumpGoalSetup(tester, controller);
      await tester.ensureVisible(find.text('はじめる'));
      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();
      _expectHealthRowOpens(tester, health);
    });

    testWidgets('連携なしで活動量を選んで終えても、設定の「活動・Health」が開ける', (tester) async {
      final controller = _controller(health: false);
      addTearDown(controller.dispose);
      final health = await _pumpGoalSetup(tester, controller);
      await tester.ensureVisible(find.text('はじめる'));
      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityLevelScreen), findsOneWidget);
      await tester.tap(find.text('はじめる'));
      await tester.pumpAndSettle();
      _expectHealthRowOpens(tester, health);
    });
  });

  group('目標の自動計算', () {
    for (final health in [true, false]) {
      for (final gender in [Gender.male, Gender.female]) {
        testWidgets(
          '初回: health=$health $gender 開いた時点と、減量・目標体重・目標日の直後に4欄に数字が入る',
          (tester) async {
            final controller = _controller(health: health, gender: gender);
            addTearDown(controller.dispose);
            await _pumpGoalSetup(tester, controller);
            _expectAllNumbers(_fields(tester));
            final maintain = int.parse(_fields(tester).first);

            await tester.tap(find.text('減量'));
            await tester.pumpAndSettle();
            _expectAllNumbers(_fields(tester));
            await tester.enterText(find.byType(EditableText).first, '65');
            await tester.pumpAndSettle();
            _expectAllNumbers(_fields(tester));
            await _setDate(tester, targetDate);
            final shown = _fields(tester);
            _expectAllNumbers(shown);
            expect(int.parse(shown.first), lessThan(maintain));
            expect(
              find.byKey(const Key('goal-auto-unavailable')),
              findsNothing,
            );
          },
        );
      }
    }

    testWidgets('設定: 開いた時点で4欄に数字が入り、方向性と日付で計算し直す', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controller(health: true);
      addTearDown(controller.dispose);
      controller.setGoal(
        Goal(
          type: GoalType.maintain,
          targetWeightKg: 70,
          targetDate: targetDate,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsGoalScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      final first = _fields(tester);
      _expectAllNumbers(first);
      await tester.tap(find.text('減量'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).first, '65');
      await tester.pumpAndSettle();
      final lose = _fields(tester);
      _expectAllNumbers(lose);
      expect(int.parse(lose.first), lessThan(int.parse(first.first)));
      await _setDate(
        tester,
        DateTime(today.year, today.month, today.day + 300),
      );
      final later = _fields(tester);
      _expectAllNumbers(later);
      expect(int.parse(later.first), greaterThan(int.parse(lose.first)));
      expect(
        controller.nutritionSettings!.calorieTargetMode,
        CalorieTargetMode.automatic,
      );
    });

    testWidgets('性別が「その他」なら、空の理由を欄の上に出す', (tester) async {
      final controller = _controller(health: true, gender: Gender.other);
      addTearDown(controller.dispose);
      await _pumpGoalSetup(tester, controller);
      expect(_fields(tester).first, isEmpty);
      expect(find.byKey(const Key('goal-auto-unavailable')), findsOneWidget);
      expect(find.textContaining('性別が「その他」'), findsOneWidget);
    });
  });

  group('入力漏れの表示と即時の再計算', () {
    testWidgets('初回: 基本情報が無いと、漏れている項目を出す', (tester) async {
      final controller = AppController(
        healthRepository: MockHealthRepository(isAvailable: false),
      );
      addTearDown(controller.dispose);
      await _pumpGoalSetup(tester, controller);
      expect(_fields(tester).first, isEmpty);
      expect(
        find.text('自動計算に必要な項目が入っていません：生年月日・性別・身長・体重・目標体重（30〜300kg）'),
        findsOneWidget,
      );
    });

    testWidgets('初回: 目標体重を消すと漏れを出し、入れ直すとすぐ埋まる', (tester) async {
      final controller = _controller(health: true);
      addTearDown(controller.dispose);
      await _pumpGoalSetup(tester, controller);
      _expectAllNumbers(_fields(tester));
      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pumpAndSettle();
      expect(_fields(tester).first, isEmpty);
      expect(find.textContaining('目標体重（30〜300kg）'), findsOneWidget);
      await tester.enterText(find.byType(EditableText).first, '68');
      await tester.pumpAndSettle();
      _expectAllNumbers(_fields(tester));
      expect(find.byKey(const Key('goal-auto-unavailable')), findsNothing);
    });

    testWidgets('設定: 目標体重の漏れを出し、体重・活動量の変更ですぐ計算し直す', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controller(health: false);
      addTearDown(controller.dispose);
      controller.setGoal(
        Goal(type: GoalType.lose, targetWeightKg: 65, targetDate: targetDate),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsGoalScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      final first = _fields(tester);
      _expectAllNumbers(first);

      controller.setNutritionSettings(
        controller.nutritionSettings!.copyWith(
          activityLevel: ActivityLevel.high,
        ),
      );
      await tester.pumpAndSettle();
      final active = _fields(tester);
      _expectAllNumbers(active);
      expect(int.parse(active.first), greaterThan(int.parse(first.first)));

      controller.setProfile(controller.profile!.copyWith(weightKg: 90));
      await tester.pumpAndSettle();
      final heavier = _fields(tester);
      _expectAllNumbers(heavier);
      expect(heavier, isNot(active));

      await tester.enterText(find.byType(EditableText).first, '');
      await tester.pumpAndSettle();
      expect(_fields(tester).first, isEmpty);
      expect(find.text('自動計算に必要な項目が入っていません：目標体重（30〜300kg）'), findsOneWidget);
    });

    testWidgets('設定: 性別が「その他」なら理由を出す', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 932));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _controller(health: true, gender: Gender.other);
      addTearDown(controller.dispose);
      controller.setGoal(
        Goal(
          type: GoalType.maintain,
          targetWeightKg: 70,
          targetDate: targetDate,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsGoalScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      expect(_fields(tester).first, isEmpty);
      expect(find.textContaining('性別が「その他」'), findsOneWidget);
    });
  });

  group('Health の性別と生年月日', () {
    test('性別は数値（1 女性 / 2 男性 / 3 その他 / 0 未設定）で読む', () {
      Gender? read(num v) =>
          genderFromHealthValue(NumericHealthValue(numericValue: v));
      expect(read(1), Gender.female);
      expect(read(2), Gender.male);
      expect(read(3), Gender.other);
      expect(read(0), isNull);
    });

    test('生年月日は値（1970年からの秒）で読み、未設定は null', () {
      final birth = DateTime(1990, 5, 20);
      final seconds = birth.millisecondsSinceEpoch / 1000;
      expect(
        birthDateFromHealthValue(NumericHealthValue(numericValue: seconds)),
        DateTime(1990, 5, 20),
      );
      expect(
        birthDateFromHealthValue(NumericHealthValue(numericValue: 0)),
        isNull,
      );
    });
  });
}
