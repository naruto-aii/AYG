import 'package:ayg/app.dart';
import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/local_write_guard.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/local_user_data_clearer_base.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
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
  pumpApp(
    WidgetTester tester, {
    AuthUser? restoredUser,
    MemoryAiDataConsent? consent,
    MockAuthenticationRepository? authRepository,
    MockDataSyncRepository? dataSync,
    LocalUserDataClearerBase? clearer,
  }) async {
    final auth =
        authRepository ??
        MockAuthenticationRepository(currentUser: restoredUser);
    addTearDown(auth.dispose);
    final sync = dataSync ?? MockDataSyncRepository();
    final controller = AppController(
      healthRepository: MockHealthRepository(isAvailable: false),
      authenticationRepository: auth,
      dataSyncRepository: sync,
      localUserDataClearer: clearer,
    );
    if (consent != null) {
      AiDataConsent.override = consent;
    }
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
    expect(find.text(AppStrings.termsConsentTitle), findsOneWidget);
    expect(find.text(AppStrings.termsConsentAi), findsOneWidget);
    expect(find.text(AppStrings.termsConsentUgc), findsOneWidget);
    expect(find.text(AppStrings.termsConsentAgree), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  }

  Future<void> agree(WidgetTester tester) async {
    await tester.tap(find.text(AppStrings.termsConsentAgree));
    await tester.pumpAndSettle();
  }

  test('サーバの版だけを見て、端末全体のフラグでは通さない', () {
    const user = 'user-1';
    expect(
      hasCurrentTermsAgreement(
        userId: user,
        cachedUserId: null,
        cachedVersion: aiDataConsentVersion,
        serverVersion: null,
        serverReadFailed: false,
      ),
      isFalse,
      reason: 'ユーザーIDの無い端末フラグは、行が無いアカウントを通さない',
    );
    expect(
      hasCurrentTermsAgreement(
        userId: user,
        cachedUserId: 'someone-else',
        cachedVersion: aiDataConsentVersion,
        serverVersion: null,
        serverReadFailed: false,
      ),
      isFalse,
      reason: '別アカウントの同意は使わない',
    );
    expect(
      hasCurrentTermsAgreement(
        userId: user,
        cachedUserId: user,
        cachedVersion: aiDataConsentVersion,
        serverVersion: '2026-10-08',
        serverReadFailed: false,
      ),
      isFalse,
      reason: '古い版は、手元が新しくてももう一度出す',
    );
    expect(
      hasCurrentTermsAgreement(
        userId: user,
        cachedUserId: null,
        cachedVersion: null,
        serverVersion: aiDataConsentVersion,
        serverReadFailed: false,
      ),
      isTrue,
      reason: '再インストールでも、今の版の行があれば出さない',
    );
    expect(
      hasCurrentTermsAgreement(
        userId: user,
        cachedUserId: user,
        cachedVersion: aiDataConsentVersion,
        serverVersion: null,
        serverReadFailed: true,
      ),
      isTrue,
      reason: 'オフラインの同意済みアカウントは止めない',
    );
    expect(
      hasCurrentTermsAgreement(
        userId: 'recreated',
        cachedUserId: 'deleted',
        cachedVersion: aiDataConsentVersion,
        serverVersion: null,
        serverReadFailed: true,
      ),
      isFalse,
      reason: '作り直したアカウントは、前の手元の控えでは通さない',
    );
  });

  test('ユーザーIDの無い古いキーは、今の版でも同意にしない', () async {
    AiDataConsent.override = null;
    SharedPreferences.setMockInitialValues({
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
    expect(await AiDataConsent.currentAgreementForUser('user-1'), isFalse);

    SharedPreferences.setMockInitialValues({
      termsAgreementUserKey: 'user-1',
      aiDataConsentVersionKey: aiDataConsentVersion,
    });
    expect(await AiDataConsent.currentAgreementForUser('user-1'), isTrue);
    expect(await AiDataConsent.currentAgreementForUser('user-2'), isFalse);
  });

  testWidgets('初めての Apple ログインは、サインインのあとに同意画面を出す', (tester) async {
    final consent = MemoryAiDataConsent(serverByUser: {});
    final (controller, auth, sync) = await pumpApp(tester, consent: consent);

    expect(find.text(AppStrings.loginWithApple), findsOneWidget);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
    expect(consent.grantCalls, 0);

    await tester.tap(find.text(AppStrings.loginWithApple));
    await tester.pumpAndSettle();

    expect(auth.loginWithAppleCalled, isTrue);
    expect(controller.isAuthenticated, isTrue);
    expect(controller.requiresTermsAgreement, isTrue);
    expectConsentScreen();
    expect(consent.grantCalls, 0, reason: '画面を見せる前に ai_data_consents へ書かない');
    expect(sync.pullRemoteToLocalCalled, isFalse);

    await agree(tester);

    expect(consent.grantCalls, 1);
    expect(consent.serverByUser?['test-user-id'], aiDataConsentVersion);
    expect(controller.requiresTermsAgreement, isFalse);
    expect(sync.pullRemoteToLocalCalled, isTrue);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
  });

  testWidgets('初めての Google ログインも、同じ同意画面を出す', (tester) async {
    final consent = MemoryAiDataConsent(serverByUser: {});
    final (controller, auth, sync) = await pumpApp(tester, consent: consent);

    await tester.tap(find.text(AppStrings.loginWithGoogle));
    await tester.pumpAndSettle();

    expect(auth.loginWithGoogleCalled, isTrue);
    expectConsentScreen();
    expect(sync.pullRemoteToLocalCalled, isFalse);

    await agree(tester);

    expect(consent.serverByUser?['test-user-id'], aiDataConsentVersion);
    expect(controller.requiresTermsAgreement, isFalse);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
  });

  testWidgets('今の版に同意済みのアカウントは、起動時に同意画面を出さない', (tester) async {
    final consent = MemoryAiDataConsent(
      serverByUser: {'agreed-user': aiDataConsentVersion},
    );
    final (controller, _, sync) = await pumpApp(
      tester,
      consent: consent,
      restoredUser: const AuthUser(id: 'agreed-user', email: 'b@example.com'),
    );

    expect(controller.requiresTermsAgreement, isFalse);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
    expect(consent.grantCalls, 0);
    expect(sync.pullRemoteToLocalCalled, isTrue);
  });

  testWidgets('アカウントを削除して作り直したら、前の端末フラグがあっても同意画面を出す', (tester) async {
    final consent = MemoryAiDataConsent(
      granted: true,
      serverByUser: {'deleted-user': aiDataConsentVersion},
    );
    final (controller, auth, sync) = await pumpApp(tester, consent: consent);
    auth.nextSignedInUserId = 'recreated-user';

    await tester.tap(find.text(AppStrings.loginWithApple));
    await tester.pumpAndSettle();

    expect(controller.requiresTermsAgreement, isTrue);
    expectConsentScreen();
    expect(sync.pullRemoteToLocalCalled, isFalse);
    expect(consent.serverByUser?['deleted-user'], aiDataConsentVersion);
    expect(consent.serverByUser?.containsKey('recreated-user'), isFalse);

    await agree(tester);

    expect(consent.serverByUser?['recreated-user'], aiDataConsentVersion);
    expect(controller.requiresTermsAgreement, isFalse);
  });

  testWidgets('再インストール後も、同意済みアカウントはサーバの行で画面を出さない', (tester) async {
    final consent = MemoryAiDataConsent(
      granted: false,
      serverByUser: {'agreed-user': aiDataConsentVersion},
    );
    final (controller, _, sync) = await pumpApp(
      tester,
      consent: consent,
      restoredUser: const AuthUser(id: 'agreed-user', email: 'b@example.com'),
    );

    expect(controller.requiresTermsAgreement, isFalse);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
    expect(consent.grantCalls, 0);
    expect(sync.pullRemoteToLocalCalled, isTrue);
  });

  testWidgets('古い版に同意したアカウントは、もう一度出して、同意後は繰り返さない', (tester) async {
    final consent = MemoryAiDataConsent(
      serverByUser: {'old-user': '2026-10-08'},
    );
    final (controller, _, sync) = await pumpApp(
      tester,
      consent: consent,
      restoredUser: const AuthUser(id: 'old-user', email: 'c@example.com'),
    );

    expect(controller.requiresTermsAgreement, isTrue);
    expectConsentScreen();
    expect(sync.pullRemoteToLocalCalled, isFalse);

    await agree(tester);

    expect(consent.serverByUser?['old-user'], aiDataConsentVersion);
    expect(controller.requiresTermsAgreement, isFalse);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
    expect(sync.pullRemoteToLocalCalled, isTrue);
  });

  testWidgets('ログインを取り消しても、同意は残さない', (tester) async {
    final consent = MemoryAiDataConsent(serverByUser: {});
    final (_, auth, _) = await pumpApp(tester, consent: consent);
    auth.simulateAppleSignInCancelled = true;

    await tester.tap(find.text(AppStrings.loginWithApple));
    await tester.pumpAndSettle();

    expect(consent.grantCalls, 0);
    expect(find.text(AppStrings.loginWithApple), findsOneWidget);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
  });

  testWidgets('同意しないとログインに戻り、サーバには書かない', (tester) async {
    final consent = MemoryAiDataConsent(serverByUser: {});
    final (controller, auth, sync) = await pumpApp(tester, consent: consent);

    await tester.tap(find.text(AppStrings.loginWithApple));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.termsConsentDecline));
    await tester.pumpAndSettle();

    expect(consent.grantCalls, 0);
    expect(auth.logoutCalled, isTrue);
    expect(controller.isAuthenticated, isFalse);
    expect(sync.pushLocalToRemoteCalled, isFalse);
    expect(sync.pullRemoteToLocalCalled, isFalse);
    expect(find.text(AppStrings.loginWithApple), findsOneWidget);
  });

  testWidgets('同意の保存に失敗しても画面に残り、もう一度押せる', (tester) async {
    final consent = MemoryAiDataConsent(serverByUser: {}, failGrant: true);
    final (controller, _, sync) = await pumpApp(tester, consent: consent);

    await tester.tap(find.text(AppStrings.loginWithApple));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.termsConsentAgree));
    await tester.pump();

    expect(find.text(AppStrings.termsConsentSaveFailed), findsOneWidget);
    expect(controller.requiresTermsAgreement, isTrue);
    expect(consent.grantCalls, 1);
    expect(sync.pullRemoteToLocalCalled, isFalse);
    expect(find.text(AppStrings.termsConsentAgree), findsOneWidget);

    consent.failGrant = false;
    await tester.tap(find.text(AppStrings.termsConsentAgree));
    await tester.pumpAndSettle();

    expect(consent.serverByUser?['test-user-id'], aiDataConsentVersion);
    expect(controller.requiresTermsAgreement, isFalse);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
  });

  testWidgets('同意しないと、送れなくてもログインに戻り、記録は消さない', (tester) async {
    final clearer = _Clearer();
    final sync = _OfflineSync();
    final consent = MemoryAiDataConsent(serverByUser: {});
    final (controller, auth, _) = await pumpApp(
      tester,
      consent: consent,
      dataSync: sync,
      clearer: clearer,
    );

    await tester.tap(find.text(AppStrings.loginWithApple));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.termsConsentDecline));
    await tester.pumpAndSettle();

    expect(auth.logoutCalled, isTrue);
    expect(controller.isAuthenticated, isFalse);
    expect(sync.pushLocalToRemoteCalled, isFalse);
    expect(clearer.calls, 0);
    expect(consent.grantCalls, 0);
    expect(find.text(AppStrings.loginWithApple), findsOneWidget);
    expect(find.text(AppStrings.termsConsentAgree), findsNothing);
  });

  testWidgets('同意しないと、送れるときも記録を消さずにログインへ戻る', (tester) async {
    final clearer = _Clearer();
    final consent = MemoryAiDataConsent(
      serverByUser: {'old-user': '2026-10-08'},
    );
    final (controller, _, sync) = await pumpApp(
      tester,
      consent: consent,
      clearer: clearer,
      restoredUser: const AuthUser(id: 'old-user', email: 'c@example.com'),
    );

    expect(find.text(AppStrings.termsConsentDecline), findsOneWidget);
    await tester.tap(find.text(AppStrings.termsConsentDecline));
    await tester.pumpAndSettle();

    expect(controller.isAuthenticated, isFalse);
    expect(sync.pushLocalToRemoteCalled, isFalse);
    expect(clearer.calls, 0);
    expect(consent.serverByUser?['old-user'], '2026-10-08');
    expect(find.text(AppStrings.loginWithApple), findsOneWidget);
  });

  testWidgets('別アカウントへ切り替えると、前の同意では画面を飛ばさない', (tester) async {
    final consent = MemoryAiDataConsent(
      serverByUser: {'agreed-user': aiDataConsentVersion},
    );
    final (controller, auth, sync) = await pumpApp(
      tester,
      consent: consent,
      restoredUser: const AuthUser(id: 'agreed-user', email: 'a@example.com'),
    );

    expect(controller.requiresTermsAgreement, isFalse);
    expect(sync.pullRemoteToLocalCalled, isTrue);

    auth.setCurrentUser(
      const AuthUser(id: 'other-user', email: 'b@example.com'),
    );
    await tester.pumpAndSettle();

    expect(controller.requiresTermsAgreement, isTrue);
    expectConsentScreen();
    expect(consent.serverByUser?.containsKey('other-user'), isFalse);
    expect(consent.grantCalls, 0);
  });
}

class _Clearer implements LocalUserDataClearerBase {
  int calls = 0;

  @override
  Future<void> clearAll() async {
    calls += 1;
  }
}

class _OfflineSync extends MockDataSyncRepository {
  @override
  Future<void> pushLocalToRemote(
    String userId, {
    LocalWriteGuard? mayWrite,
  }) async {
    pushLocalToRemoteCalled = true;
    lastUserId = userId;
    throw StateError('offline');
  }
}
