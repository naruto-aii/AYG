import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/models/activity_level.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/auth_exceptions.dart';
import 'package:ayg/screens/settings/account_deletion_screen.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final referenceDate = DateTime(2026, 7, 21);

  AppController createController(MockAuthenticationRepository authRepository) {
    final controller = AppController(
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

  Future<void> pumpDeletion(
    WidgetTester tester,
    MockAuthenticationRepository authRepository,
    AppController controller,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: AccountDeletionScreen(
          controller: controller,
          authenticationRepository: authRepository,
          supportEmail: 'support@ayg.life',
        ),
      ),
    );
  }

  testWidgets('settings opens account deletion instead of only the legal page', (
    tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository);

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
    await tester.scrollUntilVisible(find.byKey(const Key('settings-account')), 200);
    await tester.tap(find.byKey(const Key('settings-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.settingsAccountDeletion));
    await tester.pumpAndSettle();

    expect(find.byType(AccountDeletionScreen), findsOneWidget);
    expect(find.text(AppStrings.accountDeletionExecute), findsOneWidget);
    expect(find.text(AppStrings.accountDeletionBilling), findsOneWidget);

    await authRepository.dispose();
  });

  testWidgets('confirming deletion logs out', (tester) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    );
    final controller = createController(authRepository);
    await pumpDeletion(tester, authRepository, controller);

    await tester.ensureVisible(find.text(AppStrings.accountDeletionExecute));
    await tester.tap(find.text(AppStrings.accountDeletionExecute));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.accountDeletionExecute).last);
    await tester.pumpAndSettle();

    expect(authRepository.deleteOwnAccountCalled, isTrue);
    expect(authRepository.logoutCalled, isTrue);

    await authRepository.dispose();
  });

  testWidgets('apple revoke failure still logs out after the notice', (
    tester,
  ) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    )..deleteOwnAccountOutcome = const AccountDeletionOutcome(
      appleRevokeFailed: true,
    );
    final controller = createController(authRepository);
    await pumpDeletion(tester, authRepository, controller);

    await tester.ensureVisible(find.text(AppStrings.accountDeletionExecute));
    await tester.tap(find.text(AppStrings.accountDeletionExecute));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.accountDeletionExecute).last);
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.accountDeletionAppleRevokeFailed),
      findsOneWidget,
    );
    expect(authRepository.logoutCalled, isFalse);

    await tester.tap(find.text(AppStrings.accountDeletionAppleRevokeFailedClose));
    await tester.pumpAndSettle();

    expect(authRepository.logoutCalled, isTrue);

    await authRepository.dispose();
  });

  testWidgets('a missing deletion function does not log out', (tester) async {
    final authRepository = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'test@example.com'),
    )..simulateAccountDeletionUnavailable = true;
    final controller = createController(authRepository);
    await pumpDeletion(tester, authRepository, controller);

    await tester.ensureVisible(find.text(AppStrings.accountDeletionExecute));
    await tester.tap(find.text(AppStrings.accountDeletionExecute));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.accountDeletionExecute).last);
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.accountDeletionUnavailable), findsOneWidget);
    expect(authRepository.logoutCalled, isFalse);

    await authRepository.dispose();
  });
}
