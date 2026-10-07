import 'dart:io';
import 'dart:ui' as ui;

import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/consent/analytics_consent_screen.dart';
import 'package:ayg/screens/settings/how_to_use_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/share_sheet_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

Future<void> _loadZenMaru() async {
  final loader = FontLoader('ZenMaruGothic');
  for (final path in const [
    'assets/fonts/ZenMaruGothic-Regular.ttf',
    'assets/fonts/ZenMaruGothic-Medium.ttf',
    'assets/fonts/ZenMaruGothic-Bold.ttf',
  ]) {
    final bytes = File(path).readAsBytesSync();
    loader.addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadZenMaru);

  testWidgets('paywall, consent, how-to, and settings', (tester) async {
    final directory = Directory('/opt/cursor/artifacts/screenshots');
    directory.createSync(recursive: true);

    await _capture(
      tester,
      CalonaviPlusEntryScreen(
        repository: UnavailableSubscriptionRepository(),
      ),
      File('${directory.path}/paywall_legal_links.png'),
      find.text('特定商取引法に基づく表記'),
      scrollTo: find.text('特定商取引法に基づく表記'),
    );
    expect(find.text('利用規約'), findsOneWidget);
    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.textContaining('Apple ID'), findsOneWidget);
    expect(find.textContaining('24時間以上前'), findsOneWidget);
    expect(find.text('音声登録 (β)'), findsOneWidget);

    await _capture(
      tester,
      const AnalyticsConsentScreen(onDecide: _noop),
      File('${directory.path}/analytics_consent.png'),
      find.text('利用状況の記録に協力する'),
    );
    expect(find.textContaining('社長確認'), findsNothing);
    expect(find.textContaining('文案'), findsNothing);

    await _capture(
      tester,
      const HowToUseScreen(),
      File('${directory.path}/how_to_widget_voice.png'),
      find.text('ウィジェットと、音声登録 (β)'),
      scrollTo: find.text('ウィジェットと、音声登録 (β)'),
    );
    expect(find.textContaining('カロナビ+の機能です'), findsNothing);

    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final healthRepository = MockHealthRepository(isAvailable: false);
    final controller = AppController(
      healthRepository: healthRepository,
      authenticationRepository: authRepository,
    );
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
        targetDate: DateTime(2026, 10, 7).add(const Duration(days: 90)),
      ),
    );
    await _capture(
      tester,
      SettingsScreen(
        controller: controller,
        authenticationRepository: authRepository,
        healthRepository: healthRepository,
        showLockScreenMeal: true,
      ),
      File('${directory.path}/settings.png'),
      find.text('設定'),
      scrollTo: find.text('音声登録 (β)'),
    );
    expect(find.text('パーソナルコーチ (β)'), findsOneWidget);
    expect(find.text('音声登録 (β)'), findsOneWidget);
    await authRepository.dispose();
  });
}

Future<void> _noop(bool cooperate) async {}

Future<void> _capture(
  WidgetTester tester,
  Widget screen,
  File file,
  Finder visible, {
  Finder? scrollTo,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(const Size(390, 844));
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: RepaintBoundary(key: key, child: screen),
    ),
  );
  await tester.pumpAndSettle();
  final target = scrollTo;
  if (target != null) {
    await tester.scrollUntilVisible(target, 200);
    await tester.pumpAndSettle();
  }
  expect(visible, findsWidgets);
  final bytes = await tester.runAsync(
    () => pngBytesFromBoundary(key, pixelRatio: 1),
  );
  expect(bytes, isNotNull);
  file.writeAsBytesSync(bytes!);
  final image = await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  });
  expect(image!.width, greaterThan(100));
}
