import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/config/official_foods_flag.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
import 'package:ayg/screens/settings/account_deletion_screen.dart';
import 'package:ayg/screens/settings/calculation_references_screen.dart';
import 'package:ayg/screens/settings/data_source_screen.dart';
import 'package:ayg/screens/settings/how_to_use_screen.dart';
import 'package:ayg/screens/settings/settings_account_screen.dart';
import 'package:ayg/screens/settings/settings_food_master_screen.dart';
import 'package:ayg/screens/settings/settings_basic_info_screen.dart';
import 'package:ayg/screens/settings/settings_goal_screen.dart';
import 'package:ayg/screens/settings/settings_policies_screen.dart';
import 'package:ayg/screens/settings/settings_profile_screen.dart';
import 'package:ayg/screens/settings/settings_reference_screen.dart';
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
    expect(find.text('規約とポリシー'), findsOneWidget);
    expect(find.text('アカウント'), findsOneWidget);
    expect(find.text(AppStrings.settingsTokushoho), findsNothing);
    expect(find.text(AppStrings.settingsAccountDeletion), findsNothing);

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

  testWidgets('grouped settings keep the original pages one tap inside', (
    WidgetTester tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);
    OfficialFoodsFlag.debugOverride = true;
    addTearDown(() => OfficialFoodsFlag.debugOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: authRepository,
          hideHealthSettings: true,
          showLockScreenMeal: true,
          supportEmail: 'support@ayg.life',
        ),
      ),
    );

    Future<void> openRow(Key key) async {
      await tester.scrollUntilVisible(find.byKey(key), 200);
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    void expectOneLine(String text) {
      expect(find.text(text), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines,
        isFalse,
      );
    }

    await openRow(const Key('settings-references'));
    expect(find.byType(SettingsReferenceScreen), findsOneWidget);
    expectOneLine('計算根拠');
    expectOneLine('カロリー・栄養素の算出方法について');
    expectOneLine('データの出典');
    expectOneLine('100gあたりの数値と表示名');
    await tester.tap(find.text('計算根拠'));
    await tester.pumpAndSettle();
    expect(find.byType(CalculationReferencesScreen), findsOneWidget);
    expect(find.textContaining('Mifflin'), findsWidgets);
    Navigator.of(tester.element(find.byType(CalculationReferencesScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('データの出典'));
    await tester.pumpAndSettle();
    expect(find.byType(DataSourceScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(DataSourceScreen))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SettingsReferenceScreen))).pop();
    await tester.pumpAndSettle();

    await openRow(const Key('settings-policies'));
    expect(find.byType(SettingsPoliciesScreen), findsOneWidget);
    expectOneLine('利用規約');
    expectOneLine('サービスのご利用条件');
    expectOneLine('プライバシー');
    expectOneLine('個人情報の取り扱いについて');
    expectOneLine(AppStrings.settingsTokushoho);
    expectOneLine('販売条件・事業者情報');
    await tester.tap(find.text(AppStrings.settingsTokushoho));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(LegalDocumentScreen))).pop();
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(SettingsPoliciesScreen))).pop();
    await tester.pumpAndSettle();

    await openRow(const Key('settings-account'));
    expect(find.byType(SettingsAccountScreen), findsOneWidget);
    expectOneLine(AppStrings.settingsLogout);
    expectOneLine('別のアカウントで使うとき');
    expectOneLine(AppStrings.settingsAccountDeletion);
    expectOneLine(AppStrings.settingsAccountDeletionSubtitle);
    expect(find.text('test@example.com'), findsWidgets);
    await tester.tap(find.text(AppStrings.settingsAccountDeletion));
    await tester.pumpAndSettle();
    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    expect(find.text(AppStrings.accountDeletionBilling), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('settings subtitles stay on one line', (WidgetTester tester) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository: authRepository);
    final health = MockHealthRepository(isAvailable: false);
    OfficialFoodsFlag.debugOverride = true;
    addTearDown(() => OfficialFoodsFlag.debugOverride = null);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: controller,
          authenticationRepository: authRepository,
          healthRepository: health,
          showLockScreenMeal: true,
          supportEmail: 'support@ayg.life',
        ),
      ),
    );

    for (final subtitle in const [
      'はじめての操作と、無料との違い',
      '名前・体格と、目標カロリー',
      '運動・歩数・ヘルスケア連携の設定',
      'よく食べる食品の登録・管理',
      'アプリを開かず食事・運動を登録',
      '声だけで食事・運動を登録',
      '算出方法と食品データの出典',
      '利用規約、プライバシー、特商法',
      'ログアウトとアカウント削除',
    ]) {
      expect(find.text(subtitle), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(find.text(subtitle)).didExceedMaxLines,
        isFalse,
      );
    }
    expect(find.text('support@ayg.life'), findsOneWidget);
    expect(
      tester
          .renderObject<RenderParagraph>(find.text('support@ayg.life'))
          .didExceedMaxLines,
      isFalse,
    );

    await tester.scrollUntilVisible(find.byKey(const Key('settings-profile')), 200);
    await tester.tap(find.byKey(const Key('settings-profile')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsProfileScreen), findsOneWidget);
    for (final text in const [
      '基本情報',
      '名前・年齢・性別・身長・体重',
      '目標設定',
      '目標体重・目標カロリーなど',
    ]) {
      expect(find.text(text), findsOneWidget);
      expect(
        tester.renderObject<RenderParagraph>(find.text(text)).didExceedMaxLines,
        isFalse,
      );
    }
    await tester.tap(find.text('基本情報'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsBasicInfoScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(SettingsBasicInfoScreen))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('目標設定'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsGoalScreen), findsOneWidget);

    await authRepository.dispose();
  });
}
