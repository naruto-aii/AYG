import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/settings/how_to_use_screen.dart';
import 'package:ayg/screens/settings/settings_food_master_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final referenceDate = DateTime(2026, 7, 21);

  AppController createController({
    required MockAuthenticationRepository authRepository,
  }) {
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
        targetDate: referenceDate.add(const Duration(days: 90)),
      ),
    );
    return controller;
  }

  testWidgets('SettingsScreen shows operator contact email', (
    WidgetTester tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: authRepository,
          hideHealthSettings: true,
          supportEmail: 'support@ayg.life',
        ),
      ),
    );

    expect(find.text(AppStrings.settingsContactOperator), findsOneWidget);
    expect(find.text('support@ayg.life'), findsOneWidget);
    expect(find.text(AppStrings.settingsSupport), findsNothing);
    expect(find.text(AppStrings.settingsTokushoho), findsOneWidget);
    expect(find.text(AppStrings.settingsAccountDeletion), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text(AppStrings.settingsContactOperator),
      200,
    );
    await tester.tap(find.text(AppStrings.settingsContactOperator));
    await tester.pumpAndSettle();

    expect(find.text('問い合わせ先'), findsOneWidget);
    expect(find.text('support@ayg.life'), findsWidgets);
    expect(find.textContaining('順次対応'), findsOneWidget);
    expect(find.textContaining('ログインに使っているメールアドレス'), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('SettingsScreen hides operator contact when email is empty', (
    WidgetTester tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: authRepository,
          hideHealthSettings: true,
          supportEmail: '',
        ),
      ),
    );

    expect(find.text(AppStrings.settingsContactOperator), findsNothing);

    await authRepository.dispose();
  });

  testWidgets('SettingsScreen uses the public support address by default', (
    WidgetTester tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: authRepository,
          hideHealthSettings: true,
        ),
      ),
    );

    expect(find.text('support@ayg.life'), findsOneWidget);
    expect(find.textContaining('calonavi.ayg.support@gmail.com'), findsNothing);

    await authRepository.dispose();
  });

  testWidgets('SettingsScreen opens 使い方 on iOS and the web shell', (
    WidgetTester tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);

    Future<void> openHowTo({required bool webShell}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SettingsScreen(
            controller: controller,
            authenticationRepository: authRepository,
            hideHealthSettings: webShell,
            showLockScreenMeal: !webShell,
          ),
        ),
      );
      await tester.scrollUntilVisible(find.text('使い方'), 200);
      await tester.tap(find.text('使い方'));
      await tester.pumpAndSettle();
      expect(find.byType(HowToUseScreen), findsOneWidget);
      expect(find.text('使い方'), findsWidgets);
      expect(find.textContaining('今日あと'), findsOneWidget);
      expect(find.text('無料とカロナビ+'), findsOneWidget);
      expect(find.textContaining('カロナビ+'), findsWidgets);
      expect(find.textContaining('声で食事と運動を登録します'), findsOneWidget);
      expect(
        find.textContaining('音声登録 (β) は、β版として先行公開'),
        findsNothing,
      );
      expect(
        find.textContaining('β版として先行公開している機能で、カロナビ+で使えます'),
        findsNothing,
      );
      expect(find.textContaining('写真'), findsNothing);
      Navigator.of(tester.element(find.byType(HowToUseScreen))).pop();
      await tester.pumpAndSettle();
    }

    await openHowTo(webShell: true);
    await openHowTo(webShell: false);

    await authRepository.dispose();
  });

  testWidgets('food master rows describe the feature on one line', (
    WidgetTester tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsFoodMasterScreen(controller: controller),
      ),
    );

    for (final subtitle in const [
      'よく食べる組み合わせをまとめて登録',
      'よくする運動をまとめて登録',
    ]) {
      expect(find.text(subtitle), findsOneWidget);
      final paragraph = tester.renderObject<RenderParagraph>(find.text(subtitle));
      expect(paragraph.didExceedMaxLines, isFalse);
    }
    expect(find.textContaining('無料は4件まで'), findsNothing);
    expect(find.textContaining('カロナビ+'), findsNothing);

    await authRepository.dispose();
  });
}
