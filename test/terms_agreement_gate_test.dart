import 'package:ayg/app.dart';
import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AiDataConsent previous;
  setUp(() {
    previous = AiDataConsent.override!;
  });
  tearDown(() {
    AiDataConsent.override = previous;
  });

  Future<(AppController, MockAuthenticationRepository, MockDataSyncRepository)>
  pumpApp(WidgetTester tester, {AuthUser? restoredUser}) async {
    final auth = MockAuthenticationRepository(currentUser: restoredUser);
    addTearDown(auth.dispose);
    final sync = MockDataSyncRepository();
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: auth,
      dataSyncRepository: sync,
    );
    await controller.initialize();
    await tester.pumpWidget(
      AygApp(
        controller: controller,
        openFoodFactsService: OpenFoodFactsService(
          userAgent: OpenFoodFactsConfig.userAgent,
        ),
        healthRepository: MockHealthRepository(isAvailable: false),
        authenticationRepository: auth,
      ),
    );
    await tester.pumpAndSettle();
    return (controller, auth, sync);
  }

  void expectConsentScreen() {
    expect(find.text(AppStrings.loginWithApple), findsOneWidget);
    expect(find.text(AppStrings.loginLegalAgreementMultiline), findsOneWidget);
    expect(find.text(AppStrings.loginAiDisclosureMultiline), findsOneWidget);
  }

  testWidgets('再インストール後、ログイン状態が戻っても同意画面を出し、押すまで何も書かない', (
    tester,
  ) async {
    final consent = MemoryAiDataConsent();
    AiDataConsent.override = consent;
    final (controller, auth, sync) = await pumpApp(
      tester,
      restoredUser: const AuthUser(id: 'restored-user', email: 'a@example.com'),
    );

    expect(controller.isAuthenticated, isTrue);
    expect(controller.requiresTermsAgreement, isTrue);
    expectConsentScreen();
    expect(consent.isGranted, isFalse);
    expect(consent.grantCalls, 0, reason: '画面を見せる前に ai_data_consents へ書かない');
    expect(sync.pullRemoteToLocalCalled, isFalse);
    expect(sync.pushLocalToRemoteCalled, isFalse);

    await tester.tap(find.text(AppStrings.loginWithApple));
    await tester.pumpAndSettle();

    expect(auth.loginWithAppleCalled, isTrue);
    expect(consent.isGranted, isTrue);
    expect(consent.grantCalls, 1);
    expect(controller.requiresTermsAgreement, isFalse);
    expect(sync.pullRemoteToLocalCalled, isTrue);
    expect(find.text(AppStrings.loginAiDisclosureMultiline), findsNothing);
  });

  testWidgets('再インストールして新規登録した人も同意画面を通る', (tester) async {
    final consent = MemoryAiDataConsent();
    AiDataConsent.override = consent;
    final (controller, auth, _) = await pumpApp(tester);

    expectConsentScreen();
    expect(consent.grantCalls, 0);

    await tester.tap(find.text(AppStrings.loginWithGoogle));
    await tester.pumpAndSettle();

    expect(auth.loginWithGoogleCalled, isTrue);
    expect(consent.isGranted, isTrue);
    expect(consent.grantCalls, 1);
    expect(controller.requiresTermsAgreement, isFalse);
  });

  testWidgets('ログインを取り消したら同意を残さない', (tester) async {
    final consent = MemoryAiDataConsent();
    AiDataConsent.override = consent;
    final (_, auth, _) = await pumpApp(tester);
    auth.simulateAppleSignInCancelled = true;

    await tester.tap(find.text(AppStrings.loginWithApple));
    await tester.pumpAndSettle();

    expect(consent.isGranted, isFalse);
    expect(consent.grantCalls, 0);
    expectConsentScreen();
  });

  testWidgets('この端末で今の版に同意済みなら、起動時に同意画面を出さない', (tester) async {
    AiDataConsent.override = MemoryAiDataConsent(granted: true, synced: true);
    final (controller, _, sync) = await pumpApp(
      tester,
      restoredUser: const AuthUser(id: 'agreed-user', email: 'b@example.com'),
    );
    expect(controller.requiresTermsAgreement, isFalse);
    expect(find.text(AppStrings.loginAiDisclosureMultiline), findsNothing);
    expect(sync.pullRemoteToLocalCalled, isTrue);
  });

  test('版が上がった端末や、旧版が自動で書いた値は同意として扱わない', () async {
    AiDataConsent.override = null;
    SharedPreferences.setMockInitialValues({
      // 旧版がログイン状態の復元だけで書いていた値。
      'ai_data_consent_version': aiDataConsentVersion,
      'ai_data_consent_at': '2026-10-08T23:26:59Z',
    });
    expect(await AiDataConsent.grantedNow(), isFalse);

    SharedPreferences.setMockInitialValues({
      aiDataConsentVersionKey: '2026-01-01',
    });
    expect(await AiDataConsent.grantedNow(), isFalse);

    SharedPreferences.setMockInitialValues({
      aiDataConsentVersionKey: aiDataConsentVersion,
    });
    expect(await AiDataConsent.grantedNow(), isTrue);
  });
}
