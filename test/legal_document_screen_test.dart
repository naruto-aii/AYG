import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/legal/legal_document.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
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

  testWidgets('settings opens terms in a full-screen sheet with close', (
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
          supportEmail: 'calonavi.ayg.support@gmail.com',
        ),
      ),
    );

    await tester.tap(find.text('利用規約'));
    await tester.pumpAndSettle();

    expect(find.byType(LegalDocumentScreen), findsOneWidget);
    expect(find.text('利用規約'), findsWidgets);
    expect(find.byTooltip('閉じる'), findsOneWidget);
    expect(find.textContaining('ログインした時点で'), findsOneWidget);
    expect(find.textContaining('麹池成'), findsWidgets);
    expect(find.textContaining('24歳'), findsNothing);

    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalDocumentScreen), findsNothing);
    expect(find.text(AppStrings.settingsContactOperator), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('legal document screen renders privacy from assets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(document: LegalDocument.privacy),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('プライバシーポリシー'), findsOneWidget);
    expect(find.textContaining('Apple Health'), findsOneWidget);
    expect(find.textContaining('麹池成'), findsWidgets);
    expect(find.textContaining('24歳'), findsNothing);
    expect(find.textContaining('Web 版'), findsNothing);
    expect(find.byTooltip('閉じる'), findsOneWidget);
  });

  testWidgets('tokushoho screen renders from assets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(document: LegalDocument.tokushoho),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('特定商取引法に基づく表記'), findsOneWidget);
    expect(find.textContaining('麹池成'), findsWidgets);
    expect(find.textContaining('アプリ内課金'), findsOneWidget);
    expect(find.textContaining('380'), findsOneWidget);
    expect(find.textContaining('4,180'), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsOneWidget);
  });

  testWidgets('account deletion screen renders in-app steps from assets', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: LegalDocumentScreen(document: LegalDocument.accountDeletion),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('アカウント削除'), findsOneWidget);
    expect(find.textContaining('アプリ内からの削除'), findsOneWidget);
    expect(find.textContaining('公開食品'), findsOneWidget);
    expect(find.textContaining('削除済みユーザー'), findsOneWidget);
    expect(find.byTooltip('閉じる'), findsOneWidget);
  });
}
