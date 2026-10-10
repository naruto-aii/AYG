import 'dart:async';

import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/supabase_authentication_repository.dart';
import 'package:ayg/repositories/usage_record_repository.dart';
import 'package:ayg/screens/settings/account_deletion_screen.dart';
import 'package:ayg/screens/settings/settings_account_screen.dart';
import 'package:ayg/services/local_user_data_clearer_base.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('supabase sign-out runs before google and survives a google failure', () async {
    final order = <String>[];
    await signOutLocalSessionThenGoogle(
      supabaseSignOut: () async {
        order.add('supabase');
      },
      googleSignOut: () async {
        order.add('google');
        throw StateError('google down');
      },
    );
    expect(order, ['supabase', 'google']);
  });

  test('a hung google sign-out does not block logout', () async {
    final started = DateTime.now();
    await signOutLocalSessionThenGoogle(
      supabaseSignOut: () async {},
      googleSignOut: () => Completer<void>().future,
      googleTimeout: const Duration(milliseconds: 40),
    );
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 2)),
    );
  });

  test('logout finishes when a flush never returns', () async {
    final auth = MockAuthenticationRepository();
    final cleared = _Clearer();
    final controller = AppController(
      authenticationRepository: auth,
      usageRecordRepository: _HangUsage(),
      localUserDataClearer: cleared,
    );
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    await auth.loginWithGoogle();

    final started = DateTime.now();
    final left = await controller.logout(force: true);
    expect(left, isTrue);
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 8)),
    );
    expect(auth.logoutCalled, isTrue);
    expect(auth.isAuthenticated, isFalse);
    expect(cleared.calls, 1);
  });

  testWidgets('account deletion leaves the first route when logout throws', (
    tester,
  ) async {
    final auth = _ThrowingAuth();
    final controller = AppController(authenticationRepository: auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);

    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => AccountDeletionScreen(
                      controller: controller,
                      authenticationRepository: auth,
                    ),
                  ),
                );
              },
              child: const Text('設定に戻る'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('設定に戻る'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.accountDeletionExecute));
    await tester.tap(find.text(AppStrings.accountDeletionExecute));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, AppStrings.accountDeletionExecute));
    await tester.pumpAndSettle();

    expect(auth.deleteOwnAccountCalled, isTrue);
    expect(find.text('設定に戻る'), findsOneWidget);
    expect(find.text(AppStrings.settingsAccountDeletion), findsNothing);
  });

  testWidgets('settings logout returns to the first route', (tester) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    final controller = AppController(authenticationRepository: auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);

    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => SettingsAccountScreen(
                      controller: controller,
                      authenticationRepository: auth,
                    ),
                  ),
                );
              },
              child: const Text('設定の入口'),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('設定の入口'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.settingsLogout));
    await tester.tap(find.text(AppStrings.settingsLogout));
    await tester.pumpAndSettle();

    expect(auth.logoutCalled, isTrue);
    expect(find.text('設定の入口'), findsOneWidget);
    expect(find.text('アカウント'), findsNothing);
  });
}

class _HangUsage extends NoOpUsageRecordRepository {
  @override
  Future<void> flushPending() => Completer<void>().future;
}

class _Clearer implements LocalUserDataClearerBase {
  int calls = 0;

  @override
  Future<void> clearAll() async {
    calls += 1;
  }
}

class _ThrowingAuth extends MockAuthenticationRepository {
  @override
  Future<void> logout() async {
    throw StateError('google');
  }
}
