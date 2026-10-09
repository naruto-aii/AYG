import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/calculation/calorie_target_mode.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/screens/onboarding/activity_level_screen.dart';
import 'package:ayg/screens/onboarding/goal_setup_screen.dart';
import 'package:ayg/screens/settings/settings_goal_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

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

  final config = jsonDecode(
    File('.dart_tool/package_config.json').readAsStringSync(),
  );
  final packages = config['packages'] as List<dynamic>;
  final entry = packages.cast<Map<String, dynamic>>().firstWhere(
    (package) => package['name'] == 'material_symbols_icons',
  );
  final root = Uri.parse(entry['rootUri'] as String);
  final configUri = Directory.current.uri.resolve(
    '.dart_tool/package_config.json',
  );
  final file = File(
    '${configUri.resolveUri(root).toFilePath()}/lib/fonts/MaterialSymbolsRounded.ttf',
  );
  final symbols = FontLoader(
    'packages/material_symbols_icons/MaterialSymbolsRounded',
  );
  symbols.addFont(
    Future<ByteData>.value(ByteData.sublistView(file.readAsBytesSync())),
  );
  await symbols.load();
}

AppController _onboardingController() {
  final controller = AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
  );
  controller.setProfile(
    UserProfile(
      birthDate: DateTime(1990, 1, 1),
      gender: Gender.male,
      heightCm: 175,
      weightKg: 70,
    ),
  );
  return controller;
}

String _text(WidgetTester tester, String key) =>
    tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(Key(key)),
        matching: find.byType(EditableText),
        matchRoot: true,
      ),
    ).controller.text;

({String kcal, String protein, String fat, String carb}) _fields(
  WidgetTester tester,
) => (
  kcal: _text(tester, 'goal-target-kcal'),
  protein: _text(tester, 'goal-target-protein'),
  fat: _text(tester, 'goal-target-fat'),
  carb: _text(tester, 'goal-target-carb'),
);

Future<void> _setDate(WidgetTester tester, DateTime date) async {
  await tester.ensureVisible(find.text('目標日'));
  final current = find.textContaining(RegExp(r'^\d{4}年\d+月\d+日$'));
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

Future<void> _pumpOnboarding(
  WidgetTester tester,
  AppController controller, {
  GlobalKey? boundary,
}) async {
  final auth = MockAuthenticationRepository();
  addTearDown(auth.dispose);
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: GoalSetupScreen(
      controller: controller,
      openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
      authenticationRepository: auth,
    ),
  );
  await tester.pumpWidget(
    boundary == null ? app : RepaintBoundary(key: boundary, child: app),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  final today = DateTime.now();
  final targetDate = DateTime(today.year, today.month, today.day + 97);

  testWidgets('onboarding fills the automatic targets and home uses them', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _onboardingController();
    addTearDown(controller.dispose);
    await _pumpOnboarding(tester, controller);

    // 初期（維持・現体重）でも数字が入っている。
    final maintain = _fields(tester);
    expect(int.parse(maintain.kcal), greaterThan(1000));

    await tester.tap(find.text('減量'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).first,
      '65',
    );
    await tester.pumpAndSettle();
    await _setDate(tester, targetDate);

    final shown = _fields(tester);
    expect(int.parse(shown.kcal), lessThan(int.parse(maintain.kcal)));
    expect(find.text('今は自分で入力しています'), findsNothing);
    expect(
      find.textContaining('目標体重と目標日から計算した数字です。'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('はじめる'));
    await tester.tap(find.text('はじめる'));
    await tester.pumpAndSettle();
    expect(find.byType(ActivityLevelScreen), findsOneWidget);
    expect(
      controller.nutritionSettings!.calorieTargetMode,
      CalorieTargetMode.automatic,
    );
    expect(controller.goal!.type, GoalType.lose);
    expect(controller.goal!.targetWeightKg, 65);

    void expectHomeEquals() {
      final summary = controller.summary!;
      expect(summary.targetKcal.toStringAsFixed(0), shown.kcal);
      expect(summary.targetProteinG.toStringAsFixed(0), shown.protein);
      expect(summary.targetFatG.toStringAsFixed(0), shown.fat);
      expect(summary.targetCarbG.toStringAsFixed(0), shown.carb);
    }

    expectHomeEquals();
    // 次の画面（活動量）の既定「普通」のまま進んだ場合も同じ数字。
    controller.setNutritionSettings(
      controller.nutritionSettings!.copyWith(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
    expectHomeEquals();
    // ignore: avoid_print
    print(
      'onboarding example: kcal=${shown.kcal} P=${shown.protein} '
      'F=${shown.fat} C=${shown.carb}',
    );
  });

  testWidgets('a user edit switches to manual and is never overwritten', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _onboardingController();
    addTearDown(controller.dispose);
    await _pumpOnboarding(tester, controller);

    await tester.ensureVisible(find.byKey(const Key('goal-target-kcal')));
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('goal-target-kcal')),
        matching: find.byType(EditableText),
        matchRoot: true,
      ),
      '2000',
    );
    await tester.pumpAndSettle();
    expect(find.text('今は自分で入力しています'), findsOneWidget);
    final edited = _fields(tester);
    expect(edited.kcal, '2000');

    await tester.ensureVisible(find.text('減量'));
    await tester.tap(find.text('減量'));
    await tester.pumpAndSettle();
    expect(_fields(tester), edited);

    // 自動に戻すと計算し直す。
    await tester.ensureVisible(find.byKey(const Key('goal-return-automatic')));
    await tester.tap(find.byKey(const Key('goal-return-automatic')));
    await tester.pumpAndSettle();
    expect(find.text('今は自分で入力しています'), findsNothing);
    expect(_fields(tester).kcal, isNot('2000'));
  });

  testWidgets('settings goal screen recalculates while automatic', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = _onboardingController();
    addTearDown(controller.dispose);
    controller.setNutritionSettings(
      const NutritionSettings(
        useHealthIntegration: false,
        activityLevel: ActivityLevel.moderate,
      ),
    );
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
    final before = _fields(tester);
    expect(before.kcal, controller.summary!.targetKcal.toStringAsFixed(0));

    await tester.tap(find.text('減量'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).first,
      '65',
    );
    await tester.pumpAndSettle();
    final shown = _fields(tester);
    expect(int.parse(shown.kcal), lessThan(int.parse(before.kcal)));
    expect(find.text('今は自分で入力しています'), findsNothing);

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();
    // 速さの注意が出たら保存する。
    if (find.byType(AlertDialog).evaluate().isNotEmpty) {
      await tester.tap(find.widgetWithText(FilledButton, '保存'));
      await tester.pumpAndSettle();
    }
    expect(
      controller.nutritionSettings!.calorieTargetMode,
      CalorieTargetMode.automatic,
    );
    final summary = controller.summary!;
    expect(summary.targetKcal.toStringAsFixed(0), shown.kcal);
    expect(summary.targetProteinG.toStringAsFixed(0), shown.protein);
    expect(summary.targetFatG.toStringAsFixed(0), shown.fat);
    expect(summary.targetCarbG.toStringAsFixed(0), shown.carb);
  });

  testWidgets('goal setup screenshot at 1290x2796', (tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    tester.view.viewInsets = FakeViewPadding.zero;
    tester.view.systemGestureInsets = FakeViewPadding.zero;
    addTearDown(tester.view.reset);

    final controller = _onboardingController();
    addTearDown(controller.dispose);
    final key = GlobalKey();
    await _pumpOnboarding(tester, controller, boundary: key);
    await tester.tap(find.text('減量'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText).first,
      '65',
    );
    await tester.pumpAndSettle();
    await _setDate(tester, targetDate);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    // 入力（減量・目標体重・目標日）と計算結果が同じ画面に入る位置まで送る。
    await tester.ensureVisible(find.text('目標の方向性'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -190));
    await tester.pumpAndSettle();
    expect(find.text('65'), findsOneWidget);

    final bytes = await tester.runAsync(
      () => pngBytesFromBoundary(key, pixelRatio: 3),
    );
    expect(bytes, isNotNull);
    final out = Platform.environment['GOAL_SHOT_PATH'];
    if (out != null) {
      File(out).writeAsBytesSync(bytes!);
    }
    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      final shot = frame.image;
      codec.dispose();
      return shot;
    });
    expect(image!.width, 1290);
    expect(image.height, 2796);
    image.dispose();
  });
}
