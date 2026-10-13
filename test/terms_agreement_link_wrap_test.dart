import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/screens/legal/legal_document.dart';
import 'package:ayg/screens/legal/legal_document_screen.dart';
import 'package:ayg/screens/legal/terms_agreement_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';

/// 幅 320・375・390 と文字倍率 1.0・1.6・2.0・3.0 で、
/// 「利用規約」「プライバシーポリシー」の両方を押せる。
void main() {
  const widths = <double>[320, 375, 390];
  const scales = <double>[1.0, 1.6, 2.0, 3.0];

  for (final width in widths) {
    for (final scale in scales) {
      testWidgets('terms links are tappable at width $width scale $scale', (
        tester,
      ) async {
        const height = 667.0;
        final size = Size(width, height);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final controller = AppController();
        addTearDown(controller.dispose);
        final repository = MockAuthenticationRepository(
          currentUser: const AuthUser(id: 'new-user', email: 'a@example.com'),
        );
        addTearDown(repository.dispose);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: size,
              textScaler: TextScaler.linear(scale),
            ),
            child: MaterialApp(
              theme: AppTheme.light,
              home: TermsAgreementScreen(
                controller: controller,
                authenticationRepository: repository,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final terms = find.byKey(const Key('terms-agreement-terms-link'));
        final privacy = find.byKey(const Key('terms-agreement-privacy-link'));
        await tester.ensureVisible(terms);
        await tester.ensureVisible(privacy);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final termsBox = tester.getRect(terms);
        final privacyBox = tester.getRect(privacy);
        expect(termsBox.width, greaterThan(0));
        expect(privacyBox.width, greaterThan(0));
        if (scale == 1.0) {
          expect(
            (termsBox.center.dy - privacyBox.center.dy).abs(),
            lessThan(1),
            reason: '通常の文字サイズでは1行のまま',
          );
        }
        if (width == 320 && scale >= 2.0) {
          expect(
            privacyBox.top,
            greaterThan(termsBox.top),
            reason: '狭い画面の大きい文字では次の行へ折り返す',
          );
        }

        await _openLink(tester, terms, LegalDocument.terms);
        await _openLink(tester, privacy, LegalDocument.privacy);
      });
    }
  }
}

Future<void> _openLink(
  WidgetTester tester,
  Finder finder,
  LegalDocument document,
) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
  await tester.tap(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  expect(find.byType(LegalDocumentScreen), findsOneWidget);
  final screen = tester.widget<LegalDocumentScreen>(
    find.byType(LegalDocumentScreen),
  );
  expect(screen.document, document);
  final navigator = Navigator.of(
    tester.element(find.byType(LegalDocumentScreen)),
  );
  navigator.pop();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(LegalDocumentScreen), findsNothing);
  expect(tester.takeException(), isNull);
}
