import 'dart:async';

import 'package:ayg/app.dart';
import 'package:ayg/models/app_settings.dart';
import 'package:ayg/models/goal.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/nutrition_settings.dart';
import 'package:ayg/models/user_profile.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/contracts/settings_repository_base.dart';
import 'package:ayg/repositories/contracts/user_repository_base.dart';
import 'package:ayg/repositories/local_write_guard.dart';
import 'package:ayg/repositories/usage_record_repository.dart';
import 'package:ayg/services/ai_data_consent.dart';
import 'package:ayg/services/local_user_data_clearer_base.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';
import 'mocks/mock_health_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'a stalled consent read fails, and only a matching cache passes',
    (tester) async {
      final stalled = Completer<String?>();
      final pending = readTermsServerVersion(
        stalled.future,
        budget: const Duration(milliseconds: 20),
      );
      await tester.pump(const Duration(milliseconds: 30));
      final read = await pending;
      expect(read.failed, isTrue);
      expect(read.serverVersion, isNull);
      expect(
        hasCurrentTermsAgreement(
          userId: 'user-1',
          cachedUserId: 'user-1',
          cachedVersion: aiDataConsentVersion,
          serverVersion: read.serverVersion,
          serverReadFailed: read.failed,
        ),
        isTrue,
      );
      expect(
        hasCurrentTermsAgreement(
          userId: 'user-1',
          cachedUserId: null,
          cachedVersion: null,
          serverVersion: read.serverVersion,
          serverReadFailed: read.failed,
        ),
        isFalse,
      );

      final finished = await readTermsServerVersion(
        Future<String?>.value('other-version'),
      );
      expect(finished.failed, isFalse);
      expect(finished.serverVersion, 'other-version');
      expect(
        hasCurrentTermsAgreement(
          userId: 'user-1',
          cachedUserId: 'user-1',
          cachedVersion: aiDataConsentVersion,
          serverVersion: finished.serverVersion,
          serverReadFailed: finished.failed,
        ),
        isFalse,
      );
    },
  );

  testWidgets(
    'a slow first sync keeps running and still applies when it finishes',
    (tester) async {
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      addTearDown(auth.dispose);
      final meals = <String>[];
      final sync = _MealSync(meals);
      final gate = Completer<void>();
      sync.pulls.add(_Pull(['dinner'], gate: gate));
      final controller = AppController(
        authenticationRepository: auth,
        dataSyncRepository: sync,
        termsAgreedFor: (_) async => true,
      );
      addTearDown(controller.dispose);

      final pending = controller.handleAuthenticatedSession();
      await tester.pumpWidget(_app(controller, auth));
      await tester.pump();

      expect(find.text('読み込み中…'), findsOneWidget);
      expect(find.text('再試行'), findsOneWidget);
      expect(find.text('ログアウト'), findsOneWidget);
      expect(controller.requiresSyncRetry, isFalse);
      expect(controller.hasInitialSyncCompleted, isFalse);

      await tester.pump(const Duration(seconds: 30));
      expect(controller.requiresSyncRetry, isFalse);
      expect(controller.isSyncInProgress, isTrue);
      expect(find.text('通信に失敗しました'), findsNothing);

      gate.complete();
      await pending;
      await tester.pump();

      expect(meals, ['dinner']);
      expect(controller.hasInitialSyncCompleted, isTrue);
      expect(controller.requiresSyncRetry, isFalse);
      expect(find.text('読み込み中…'), findsNothing);
      expect(find.text('再試行'), findsNothing);
    },
  );

  testWidgets(
    'a fetch that returns after retry does not overwrite the retry result',
    (tester) async {
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      addTearDown(auth.dispose);
      final meals = <String>[];
      final sync = _MealSync(meals);
      final late = Completer<void>();
      sync.pulls.add(_Pull(['old-snapshot'], gate: late));
      sync.pulls.add(_Pull(['retry-result']));
      final controller = AppController(
        authenticationRepository: auth,
        dataSyncRepository: sync,
        termsAgreedFor: (_) async => true,
      );
      addTearDown(controller.dispose);

      final first = controller.handleAuthenticatedSession();
      await tester.pumpWidget(_app(controller, auth));
      await tester.pump();
      expect(sync.started, 1);

      await tester.tap(find.text('再試行'));
      for (var i = 0; i < 20 && meals.isEmpty; i++) {
        await tester.pump();
      }

      expect(meals, ['retry-result']);
      expect(controller.hasInitialSyncCompleted, isTrue);

      late.complete();
      await first;
      await tester.pump();

      expect(meals, ['retry-result']);
      expect(sync.blocked, ['old-snapshot']);
      expect(controller.hasInitialSyncCompleted, isTrue);
      expect(controller.requiresSyncRetry, isFalse);
    },
  );

  testWidgets('a fetch is dropped when the generation advanced by two', (
    tester,
  ) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    addTearDown(auth.dispose);
    final meals = <String>[];
    final sync = _MealSync(meals);
    final firstGate = Completer<void>();
    final secondGate = Completer<void>();
    sync.pulls.add(_Pull(['generation-1'], gate: firstGate));
    sync.pulls.add(_Pull(['generation-2'], gate: secondGate));
    sync.pulls.add(_Pull(['generation-3']));
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: sync,
      termsAgreedFor: (_) async => true,
    );
    addTearDown(controller.dispose);

    final first = controller.handleAuthenticatedSession();
    await tester.pump();
    final second = controller.retryAuthenticatedSync();
    await tester.pump();
    final third = controller.retryAuthenticatedSync();
    await tester.pump();
    await third;

    expect(meals, ['generation-3']);

    secondGate.complete();
    firstGate.complete();
    await second;
    await first;

    expect(meals, ['generation-3']);
    expect(sync.blocked, containsAll(['generation-1', 'generation-2']));
    expect(controller.hasInitialSyncCompleted, isTrue);
    expect(controller.requiresSyncRetry, isFalse);
  });

  testWidgets(
    'a late fetch after logout is not written back onto the next account',
    (tester) async {
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-a', email: 'a@example.com'),
      );
      addTearDown(auth.dispose);
      final meals = <String>['unsent-local'];
      final sync = _MealSync(meals);
      final late = Completer<void>();
      sync.pulls.add(_Pull(['previous-user-meal'], gate: late));
      sync.pulls.add(_Pull(['user-b-meal']));
      final controller = AppController(
        authenticationRepository: auth,
        dataSyncRepository: sync,
        localUserDataClearer: _Clearer(meals),
        termsAgreedFor: (_) async => true,
      );
      addTearDown(controller.dispose);

      final first = controller.handleAuthenticatedSession();
      await tester.pump();
      expect(sync.started, 1);

      final left = await controller.logout();
      expect(left, isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(meals, isEmpty);

      auth.setCurrentUser(const AuthUser(id: 'user-b', email: 'b@example.com'));
      await controller.handleAuthenticatedSession();
      expect(meals, ['user-b-meal']);
      expect(
        sync.pushed.every((rows) => !rows.contains('previous-user-meal')),
        isTrue,
      );

      late.complete();
      await first;
      await tester.pump();

      expect(meals, ['user-b-meal']);
      expect(sync.blocked, ['previous-user-meal']);
      expect(
        sync.pushed.every((rows) => !rows.contains('previous-user-meal')),
        isTrue,
      );
      expect(controller.profile, isNull);
    },
  );

  testWidgets('a token refresh does not open the retry screen', (tester) async {
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    addTearDown(auth.dispose);
    final profiles = _Users();
    final controller = AppController(
      authenticationRepository: auth,
      dataSyncRepository: MockDataSyncRepository(),
      userRepository: profiles,
      settingsRepository: _Settings(),
      termsAgreedFor: (_) async => true,
    );
    addTearDown(controller.dispose);

    await controller.handleAuthenticatedSession();
    expect(controller.hasInitialSyncCompleted, isTrue);
    expect(controller.requiresSyncRetry, isFalse);

    await tester.pumpWidget(_app(controller, auth));
    await tester.pump();
    expect(find.text('再試行'), findsNothing);
    expect(find.text('読み込み中…'), findsNothing);

    final refresh = controller.handleAuthenticatedSession();
    await tester.pump();
    expect(controller.isSyncInProgress, isTrue);
    expect(controller.requiresSyncRetry, isFalse);
    expect(controller.hasInitialSyncCompleted, isTrue);
    expect(find.text('再試行'), findsNothing);
    expect(find.text('データの取得に失敗しました'), findsNothing);

    profiles.release.completeError(StateError('token refresh'));
    await refresh;
    await tester.pump();

    expect(controller.requiresSyncRetry, isFalse);
    expect(controller.hasInitialSyncCompleted, isTrue);
    expect(find.text('再試行'), findsNothing);
    expect(find.text('データの取得に失敗しました'), findsNothing);
  });

  testWidgets(
    'a stalled analytics flush does not hold the first loading screen',
    (tester) async {
      final auth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
      );
      addTearDown(auth.dispose);
      final usage = _HangUsage();
      final controller = AppController(
        authenticationRepository: auth,
        dataSyncRepository: MockDataSyncRepository(),
        usageRecordRepository: usage,
        termsAgreedFor: (_) async => true,
      );
      addTearDown(controller.dispose);

      final pending = controller.initialize();
      await tester.pumpWidget(_app(controller, auth));
      await pending.timeout(const Duration(seconds: 2));
      await tester.pump();

      expect(controller.isInitializing, isFalse);
      expect(controller.isSyncInProgress, isFalse);
      expect(find.text('読み込み中…'), findsNothing);
      expect(usage.gate.isCompleted, isFalse);
      usage.gate.complete();
    },
  );
}

Widget _app(AppController controller, MockAuthenticationRepository auth) {
  return AygApp(
    controller: controller,
    openFoodFactsService: OpenFoodFactsService(userAgent: 'test'),
    healthRepository: MockHealthRepository(isAvailable: false),
    authenticationRepository: auth,
  );
}

class _Pull {
  _Pull(this.rows, {this.gate});

  final List<String> rows;
  final Completer<void>? gate;
}

class _MealSync extends MockDataSyncRepository {
  _MealSync(this.meals);

  final List<String> meals;
  final pulls = <_Pull>[];
  final pushed = <List<String>>[];
  final blocked = <String>[];
  int started = 0;

  @override
  Future<void> pullRemoteToLocal(
    String userId, {
    Set<String> skipTables = const {},
    LocalWriteGuard? mayWrite,
  }) async {
    pullRemoteToLocalCalled = true;
    lastUserId = userId;
    started++;
    final pull = pulls.removeAt(0);
    final gate = pull.gate;
    if (gate != null) {
      await gate.future;
    }
    final label = pull.rows.join(',');
    if (!localWriteAllowed(mayWrite)) {
      blocked.add(label);
      return;
    }
    meals
      ..clear()
      ..addAll(pull.rows);
  }

  @override
  Future<void> pushLocalToRemote(
    String userId, {
    LocalWriteGuard? mayWrite,
  }) async {
    pushLocalToRemoteCalled = true;
    lastUserId = userId;
    if (!localWriteAllowed(mayWrite)) {
      blocked.add('push:$userId');
      return;
    }
    pushed.add(List<String>.from(meals));
  }
}

class _Clearer implements LocalUserDataClearerBase {
  _Clearer(this.meals);

  final List<String> meals;

  @override
  Future<void> clearAll() async {
    meals.clear();
  }
}

class _HangUsage extends NoOpUsageRecordRepository {
  final gate = Completer<void>();

  @override
  Future<void> flushPending() => gate.future;
}

class _Users implements UserRepositoryBase {
  int calls = 0;
  final release = Completer<UserProfile?>();

  @override
  Future<UserProfile?> loadProfile() {
    calls++;
    if (calls == 1) {
      return Future<UserProfile?>.value();
    }
    return release.future;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {}

  @override
  Future<Goal?> loadGoal() async => null;

  @override
  Future<void> saveGoal(Goal goal) async {}

  @override
  Future<void> clearAll() async {}
}

class _Settings implements SettingsRepositoryBase {
  @override
  Future<void> saveNutritionSettings(NutritionSettings settings) async {}

  @override
  Future<NutritionSettings?> loadNutritionSettings() async => null;

  @override
  Future<void> saveHealthSnapshot(HealthSnapshot snapshot) async {}

  @override
  Future<HealthSnapshot?> loadHealthSnapshot() async => null;

  @override
  Future<void> saveAppSettings(AppSettings settings) async {}

  @override
  Future<AppSettings> loadAppSettings() async => const AppSettings();

  @override
  Future<void> clearAll() async {}
}
