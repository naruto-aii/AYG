import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/screens/auth/login_screen.dart';
import 'package:ayg/screens/legal/terms_agreement_screen.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

/// iPhone SE（375x667）と大きい文字（1.35倍）で、はみ出しエラーが出ないこと。
void main() {
  const sizes = {'SE': Size(375, 667), 'Pro Max': Size(430, 932)};

  Future<void> pumpAt(WidgetTester tester, Size size, Widget home) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: const TextScaler.linear(1.35),
        ),
        child: MaterialApp(theme: AppTheme.light, home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final entry in sizes.entries) {
    testWidgets('paywall has no overflow on ${entry.key} with large text', (
      tester,
    ) async {
      await pumpAt(
        tester,
        entry.value,
        CalonaviPlusEntryScreen(
          repository: UnavailableSubscriptionRepository(),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('購入を復元'), findsOneWidget);

      // 「その他の機能を見る」のシートも、大きい文字ではみ出さない。
      await tester.ensureVisible(find.byKey(const Key('plus-more-features')));
      await tester.tap(find.byKey(const Key('plus-more-features')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('カロナビ+のその他の機能'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('plus-more-features-close')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('plus-more-features-close')));
      await tester.pumpAndSettle();
      expect(find.text('カロナビ+のその他の機能'), findsNothing);
    });

    testWidgets(
      'login screen has no overflow on ${entry.key} with large text',
      (tester) async {
        final controller = AppController();
        addTearDown(controller.dispose);
        final repository = MockAuthenticationRepository();
        addTearDown(repository.dispose);
        await pumpAt(
          tester,
          entry.value,
          LoginScreen(
            controller: controller,
            authenticationRepository: repository,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('同意してから使い始めます'), findsOneWidget);
      },
    );

    testWidgets(
      'terms screen has no overflow on ${entry.key} with large text',
      (tester) async {
        final controller = AppController();
        addTearDown(controller.dispose);
        final repository = MockAuthenticationRepository(
          currentUser: const AuthUser(id: 'new-user', email: 'a@example.com'),
        );
        addTearDown(repository.dispose);
        await pumpAt(
          tester,
          entry.value,
          TermsAgreementScreen(
            controller: controller,
            authenticationRepository: repository,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Anthropic, PBC（米国）'), findsOneWidget);
        expect(find.textContaining('一切認めません'), findsOneWidget);
      },
    );
  }
}
