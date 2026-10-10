import 'dart:async';

import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/repositories/usage_record_repository.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/server_plus_store.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_authentication_repository.dart';
import 'mocks/mock_data_sync_repository.dart';

const _userId = 'reviewer';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'a late accepted does not reopen after a newer generation was bound to another account',
    () async {
      final gateway = _Gateway();
      final store = ServerPlusStore.memory();
      final started = Completer<void>();
      final first = Completer<StoreEntitlementVerification>();
      final usage = _HoldingUsage(
        onCall: (call) {
          if (call == 0) {
            started.complete();
            return first.future;
          }
          return Future.value(StoreEntitlementVerification.boundToOtherAccount);
        },
      );
      final auth = _auth();
      final controller = _controller(
        gateway: gateway,
        store: store,
        usage: usage,
        auth: auth,
      );
      addTearDown(() async {
        await auth.dispose();
        controller.dispose();
      });

      final original = controller.handleAuthenticatedSession();
      await _until(() => started.isCompleted, 'the first verify did not start');
      await controller.retryAuthenticatedSync();
      expect(gateway.paid, isFalse);
      expect((await store.read(_userId))?.blocked, isTrue);

      first.complete(_open);
      await original;
      await Future<void>.delayed(Duration.zero);

      expect(gateway.paid, isFalse);
      expect(gateway.history.contains(true), isFalse);
      final saved = await store.read(_userId);
      expect(saved?.blocked, isTrue);
      expect(saved?.plus, isFalse);
    },
  );

  test(
    'a verify that returns during logout does not turn the flag back on',
    () async {
      final gateway = _Gateway();
      final store = ServerPlusStore.memory();
      final started = Completer<void>();
      final first = Completer<StoreEntitlementVerification>();
      final usage = _HoldingUsage(
        onCall: (call) {
          if (call == 0) {
            started.complete();
            return first.future;
          }
          return Future.value(StoreEntitlementVerification.notSent);
        },
      );
      final auth = _auth();
      final controller = _controller(
        gateway: gateway,
        store: store,
        usage: usage,
        auth: auth,
      );
      addTearDown(() async {
        await auth.dispose();
        controller.dispose();
      });

      final pending = controller.initialize();
      await _until(
        () => started.isCompleted,
        'verify did not start during launch',
      );
      expect(await controller.logout(force: true), isTrue);
      expect(controller.isAuthenticated, isFalse);
      expect(gateway.paid, isFalse);

      first.complete(_open);
      await pending;
      await Future<void>.delayed(Duration.zero);

      expect(gateway.paid, isFalse);
      expect(gateway.history.contains(true), isFalse);
      expect(await store.read(_userId), isNull);
    },
  );

  test(
    'a confirmed period stays open across launches, and a refund or another user closes it',
    () async {
      final store = ServerPlusStore.memory();
      final usage = _MutableUsage(_open);
      final firstGateway = _Gateway();
      final firstAuth = _auth();
      final first = _controller(
        gateway: firstGateway,
        store: store,
        usage: usage,
        plus: _Plus(false),
        auth: firstAuth,
      );
      addTearDown(() async {
        await firstAuth.dispose();
        first.dispose();
      });

      expect(await first.ensurePaidShortcutsReady(), isTrue);
      expect(firstGateway.paid, isTrue);

      usage.verification = StoreEntitlementVerification.rejected;
      await first.syncPlusEntitlementToServer();
      expect(firstGateway.paid, isTrue);

      usage.verification = StoreEntitlementVerification.notSent;
      final secondGateway = _Gateway();
      final secondAuth = _auth();
      final second = AppController(
        authenticationRepository: secondAuth,
        lockScreenMealGateway: secondGateway,
        subscriptionRepository: _Plus(false),
        usageRecordRepository: usage,
        serverPlusStore: store,
        termsAgreedFor: (_) async => true,
      );
      addTearDown(() async {
        await secondAuth.dispose();
        second.dispose();
      });
      await second.initialize();
      expect(secondGateway.paid, isTrue);
      expect(secondGateway.history, [true]);

      final otherGateway = _Gateway();
      final otherAuth = MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'someone-else', email: 'b@example.com'),
      );
      final other = AppController(
        authenticationRepository: otherAuth,
        lockScreenMealGateway: otherGateway,
        subscriptionRepository: _Plus(true),
        usageRecordRepository: _MutableUsage(
          StoreEntitlementVerification.notSent,
        ),
        serverPlusStore: store,
        termsAgreedFor: (_) async => true,
      );
      addTearDown(() async {
        await otherAuth.dispose();
        other.dispose();
      });
      await other.initialize();
      expect(otherGateway.paid, isFalse);
      expect(otherGateway.history.contains(true), isFalse);

      usage.verification = const StoreEntitlementVerification(
        outcome: StoreVerifyOutcome.accepted,
        plus: false,
      );
      final device = _Plus(true);
      final refundGateway = _Gateway();
      final refundAuth = _auth();
      final refund = _controller(
        gateway: refundGateway,
        store: store,
        usage: usage,
        plus: device,
        auth: refundAuth,
      );
      addTearDown(() async {
        await refundAuth.dispose();
        refund.dispose();
      });
      await refund.refreshPaidEntitlement();
      expect(device.isPlusActive, isTrue);
      expect(refundGateway.paid, isFalse);

      usage.verification = StoreEntitlementVerification.boundToOtherAccount;
      await store.write(
        _userId,
        ServerPlusSnapshot(
          plus: true,
          blocked: false,
          expiresAt: DateTime.utc(2099),
        ),
      );
      final reboundGateway = _Gateway();
      final reboundAuth = _auth();
      final rebound = _controller(
        gateway: reboundGateway,
        store: store,
        usage: usage,
        plus: _Plus(true),
        auth: reboundAuth,
      );
      addTearDown(() async {
        await reboundAuth.dispose();
        rebound.dispose();
      });
      expect(await rebound.ensurePaidShortcutsReady(), isFalse);
      expect(reboundGateway.paid, isFalse);

      usage.verification = _open;
      expect(await rebound.ensurePaidShortcutsReady(), isTrue);
      expect(reboundGateway.paid, isTrue);
    },
  );

  test('a saved expiry that has passed does not open the flag', () async {
    final store = ServerPlusStore.memory();
    await store.write(
      _userId,
      ServerPlusSnapshot(
        plus: true,
        blocked: false,
        expiresAt: DateTime.utc(2020),
      ),
    );
    final gateway = _Gateway();
    final auth = _auth();
    final controller = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
      subscriptionRepository: _Plus(true),
      usageRecordRepository: _MutableUsage(
        StoreEntitlementVerification.notSent,
      ),
      serverPlusStore: store,
      termsAgreedFor: (_) async => true,
    );
    addTearDown(() async {
      await auth.dispose();
      controller.dispose();
    });

    await controller.initialize();
    expect(gateway.paid, isFalse);
    expect(gateway.history.contains(true), isFalse);
  });

  test('the confirmed result is stored per user id', () async {
    SharedPreferences.setMockInitialValues({});
    const user = 'User-A';
    final store = ServerPlusStore();
    await store.write(
      user,
      ServerPlusSnapshot(
        plus: true,
        blocked: false,
        expiresAt: DateTime.utc(2099),
      ),
    );
    final again = ServerPlusStore();
    final loaded = await again.read('user-a');
    expect(loaded?.plus, isTrue);
    expect(loaded?.blocked, isFalse);
    expect(loaded?.opensAt(DateTime.utc(2080)), isTrue);
    expect(loaded?.opensAt(DateTime.utc(2100)), isFalse);
    expect(await again.read('user-b'), isNull);
  });
}

StoreEntitlementVerification get _open => StoreEntitlementVerification(
  outcome: StoreVerifyOutcome.accepted,
  plus: true,
  expiresAt: DateTime.utc(2099),
);

MockAuthenticationRepository _auth() {
  return MockAuthenticationRepository(
    currentUser: const AuthUser(id: _userId, email: 'reviewer@example.com'),
  );
}

AppController _controller({
  required _Gateway gateway,
  required ServerPlusStore store,
  required UsageRecordRepository usage,
  required MockAuthenticationRepository auth,
  _Plus? plus,
}) {
  return AppController(
    authenticationRepository: auth,
    dataSyncRepository: MockDataSyncRepository(),
    lockScreenMealGateway: gateway,
    subscriptionRepository: plus ?? _Plus(true),
    usageRecordRepository: usage,
    serverPlusStore: store,
    termsAgreedFor: (_) async => true,
  );
}

Future<void> _until(bool Function() done, String reason) async {
  for (var i = 0; i < 40 && !done(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(done(), isTrue, reason: reason);
}

class _HoldingUsage extends NoOpUsageRecordRepository {
  _HoldingUsage({required this.onCall});

  final Future<StoreEntitlementVerification> Function(int call) onCall;
  var calls = 0;

  @override
  bool get syncsStoreEntitlements => true;

  @override
  Future<StoreEntitlementVerification> syncPlusEntitlements({
    required List<SubscriptionEntitlementRecord> confirmed,
    required List<SubscriptionEntitlementRecord> inactive,
    required bool authoritative,
    DateTime? now,
  }) {
    final call = calls;
    calls += 1;
    return onCall(call);
  }
}

class _MutableUsage extends NoOpUsageRecordRepository {
  _MutableUsage(this.verification);

  StoreEntitlementVerification verification;

  @override
  bool get syncsStoreEntitlements => true;

  @override
  Future<StoreEntitlementVerification> syncPlusEntitlements({
    required List<SubscriptionEntitlementRecord> confirmed,
    required List<SubscriptionEntitlementRecord> inactive,
    required bool authoritative,
    DateTime? now,
  }) async {
    return verification;
  }
}

class _Plus extends UnavailableSubscriptionRepository {
  _Plus(this.active);

  bool active;

  @override
  bool get isPlusActive => active;

  @override
  Stream<bool> get plusChanges => const Stream.empty();
}

class _Gateway implements LockScreenMealGateway {
  bool paid = false;
  final history = <bool>[];

  @override
  Future<void> acknowledge(List<String> registrationIds) async {}

  @override
  Future<bool> isPaid() async => paid;

  @override
  Future<LockScreenMealConfig> loadConfig() async {
    return LockScreenMealConfig.defaults();
  }

  @override
  Future<void> publishSnapshot(LockScreenMealSnapshot snapshot) async {}

  @override
  Future<List<PendingLockScreenMeal>> readPending() async => const [];

  @override
  Future<void> saveConfig(LockScreenMealConfig config) async {}

  @override
  Future<void> setPaid(bool isPaid) async {
    paid = isPaid;
    history.add(isPaid);
  }
}
