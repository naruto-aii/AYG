import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/local_session_store.dart';
import 'package:ayg/screens/settings/ai_sending_switch.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/photo_meal_client.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    AiDataConsent.override = null;
    AiDataConsent.sessionUserIdForTest = null;
    AiDataConsent.readSendingForTest = null;
  });

  testWidgets('the settings switch turns AI sending off and blocks a send', (
    tester,
  ) async {
    final memory = MemoryAiDataConsent(granted: true, synced: true);
    AiDataConsent.override = memory;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AiSendingSwitch()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AIへの送信'), findsOneWidget);
    expect(find.textContaining('手入力の記録はそのまま使えます'), findsOneWidget);
    expect(memory.sendingEnabled, isTrue);
    await ensureAiSendingEnabled();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(memory.sendingEnabled, isFalse);
    expect(
      ensureAiSendingEnabled,
      throwsA(
        isA<PhotoMealFailure>().having(
          (error) => error.message,
          'message',
          aiSendingOffMessage,
        ),
      ),
    );
  });

  testWidgets('a failed save leaves AI sending on', (tester) async {
    final memory = MemoryAiDataConsent(
      granted: true,
      synced: true,
      failGrant: true,
    );
    AiDataConsent.override = memory;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: AiSendingSwitch()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(memory.sendingEnabled, isTrue);
    expect(find.textContaining('保存できませんでした'), findsOneWidget);
  });

  test(
    'another account does not inherit the previous AI sending value',
    () async {
      AiDataConsent.override = null;
      SharedPreferences.setMockInitialValues({
        aiSendingEnabledKey: false,
        aiSendingEnabledUserKey: 'user-a',
      });
      final preferences = await SharedPreferences.getInstance();
      var session = 'user-b';
      AiDataConsent.sessionUserIdForTest = () => session;
      final server = <String, bool>{'user-a': false, 'user-b': false};
      final store = PrefsAiDataConsent(
        preferences,
        sessionUserId: () => session,
        readServerSending: (userId) async => server[userId],
      );

      expect(
        store.sendingEnabled,
        isTrue,
        reason: 'user-b does not keep user-a off',
      );
      await ensureAiSendingEnabled();

      await store.refreshSendingForSession();
      expect(preferences.getString(aiSendingEnabledUserKey), 'user-b');
      expect(preferences.getBool(aiSendingEnabledKey), isFalse);
      expect(store.sendingEnabled, isFalse);
      session = 'USER-B';
      expect(
        store.sendingEnabled,
        isFalse,
        reason: 'the same account matches ignoring case',
      );
      await expectLater(
        ensureAiSendingEnabled(),
        throwsA(
          isA<PhotoMealFailure>().having(
            (error) => error.message,
            'message',
            aiSendingOffMessage,
          ),
        ),
      );

      session = 'user-c';
      expect(
        store.sendingEnabled,
        isTrue,
        reason: 'user-c does not keep user-b off',
      );
      server.remove('user-c');
      await store.refreshSendingForSession();
      expect(preferences.getBool(aiSendingEnabledKey), isTrue);
      expect(preferences.getString(aiSendingEnabledUserKey), 'user-c');
      expect(store.sendingEnabled, isTrue);

      session = 'user-b';
      server['user-b'] = false;
      var sessionDuringRead = 'user-b';
      final racing = PrefsAiDataConsent(
        preferences,
        sessionUserId: () => sessionDuringRead,
        readServerSending: (userId) async {
          sessionDuringRead = 'user-c';
          return false;
        },
      );
      await racing.refreshSendingForSession();
      expect(preferences.getString(aiSendingEnabledUserKey), 'user-c');
      expect(preferences.getBool(aiSendingEnabledKey), isTrue);

      final failing = PrefsAiDataConsent(
        preferences,
        sessionUserId: () => 'user-a',
        readServerSending: (userId) async {
          throw StateError('offline');
        },
      );
      await failing.refreshSendingForSession();
      expect(preferences.getString(aiSendingEnabledUserKey), 'user-c');
      expect(failing.sendingEnabled, isTrue);

      await store.clearLocalSending();
      expect(preferences.containsKey(aiSendingEnabledKey), isFalse);
      expect(preferences.containsKey(aiSendingEnabledUserKey), isFalse);
      expect(store.sendingEnabled, isTrue);
    },
  );

  test(
    'login reloads AI sending for that account and logout clears it',
    () async {
      AiDataConsent.override = null;
      SharedPreferences.setMockInitialValues({
        aiSendingEnabledKey: false,
        aiSendingEnabledUserKey: 'user-a',
        'last_authenticated_user_id': 'user-a',
      });
      AiDataConsent.sessionUserIdForTest = () => 'user-b';
      var reads = 0;
      AiDataConsent.readSendingForTest = (userId) async {
        reads += 1;
        expect(userId, 'user-b');
        return true;
      };
      final preferences = await SharedPreferences.getInstance();
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-b', email: 'b@example.com'),
      );
      final sync = MockDataSyncRepository();
      final controller = AppController(
        authenticationRepository: auth,
        dataSyncRepository: sync,
        localSessionStore: LocalSessionStore(preferences: preferences),
        termsAgreedFor: (_) async => true,
      );
      addTearDown(controller.dispose);
      addTearDown(auth.dispose);

      await controller.handleAuthenticatedSession();

      expect(reads, 2);
      expect(preferences.getString(aiSendingEnabledUserKey), 'user-b');
      expect(preferences.getBool(aiSendingEnabledKey), isTrue);
      expect(await AiDataConsent.isSendingEnabled(), isTrue);
      await ensureAiSendingEnabled();

      AiDataConsent.readSendingForTest = (userId) async => false;
      final left = await controller.logout(force: true);
      expect(left, isTrue);
      expect(preferences.containsKey(aiSendingEnabledKey), isFalse);
      expect(preferences.containsKey(aiSendingEnabledUserKey), isFalse);
      expect(await AiDataConsent.isSendingEnabled(), isTrue);
      await ensureAiSendingEnabled();
    },
  );
}
