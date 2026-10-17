import 'dart:io';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/meal_template.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/complimentary_plus_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/repositories/usage_record_repository.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/server_plus_store.dart';
import 'package:ayg/services/shortcut_access.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 17, 9);
  final future = DateTime.utc(2099, 1, 1);
  final past = DateTime.utc(2020, 1, 1);

  ShortcutAccess access({
    ShortcutGrantSource source = ShortcutGrantSource.none,
    DateTime? expiresAt,
    PlusStoreSnapshot store = const PlusStoreFailed(),
  }) {
    return decideShortcutAccess(
      source: source,
      expiresAt: expiresAt,
      store: store,
      now: now,
    );
  }

  test('free, paid, expired, refunded, and complimentary follow one order', () {
    expect(access(), ShortcutAccess.unpaid);
    expect(
      access(store: const PlusStoreNone()),
      ShortcutAccess.unpaid,
    );
    expect(
      access(source: ShortcutGrantSource.store, expiresAt: future),
      ShortcutAccess.paid,
    );
    expect(
      access(source: ShortcutGrantSource.store, expiresAt: past),
      ShortcutAccess.expired,
    );
    expect(
      access(source: ShortcutGrantSource.store, expiresAt: now),
      ShortcutAccess.expired,
    );
    expect(
      access(
        source: ShortcutGrantSource.store,
        expiresAt: future,
        store: const PlusStoreRevoked(),
      ),
      ShortcutAccess.refunded,
    );
    expect(
      access(
        source: ShortcutGrantSource.revoked,
        expiresAt: future,
        store: const PlusStoreFailed(),
      ),
      ShortcutAccess.refunded,
    );
    expect(
      access(
        source: ShortcutGrantSource.complimentary,
        store: const PlusStoreRevoked(),
      ),
      ShortcutAccess.paid,
    );
    expect(
      access(source: ShortcutGrantSource.preview, store: const PlusStoreNone()),
      ShortcutAccess.paid,
    );
    expect(
      access(
        source: ShortcutGrantSource.preview,
        store: const PlusStoreRevoked(),
      ),
      ShortcutAccess.paid,
    );
    expect(access(store: const PlusStoreRevoked()), ShortcutAccess.refunded);
    expect(
      access(store: PlusStoreActive(expiresAt: future)),
      ShortcutAccess.paid,
    );
    expect(
      access(store: const PlusStoreActive()),
      ShortcutAccess.paid,
    );
    expect(
      access(
        source: ShortcutGrantSource.revoked,
        store: PlusStoreActive(expiresAt: future),
      ),
      ShortcutAccess.paid,
    );
    expect(
      access(store: PlusStoreActive(expiresAt: past)),
      ShortcutAccess.expired,
    );
  });

  test('widget chrome and presses distinguish a locked face from a paid one', () {
    for (final locked in [
      ShortcutAccess.unpaid,
      ShortcutAccess.expired,
      ShortcutAccess.refunded,
    ]) {
      final chrome = widgetChromeFor(locked);
      expect(chrome.showsRecordButtons, isFalse);
      expect(chrome.showsTapHint, isFalse);
      expect(chrome.showsPlusLock, isTrue);
      final press = widgetPress(access: locked, hasPattern: true);
      expect(press.records, isFalse);
      expect(press.opensPaywall, isTrue);
      expect(press.entryPoint, 'widget');
      expect(press.result, shortcutAnalyticsResult(locked));
    }

    final paid = widgetPress(access: ShortcutAccess.paid, hasPattern: true);
    expect(paid.records, isTrue);
    expect(paid.opensPaywall, isFalse);
    expect(paid.entryPoint, isNull);
    expect(paid.result, 'registered');
    expect(paid.chrome.showsRecordButtons, isTrue);
    expect(paid.chrome.showsTapHint, isTrue);
    expect(paid.chrome.showsPlusLock, isFalse);

    final empty = widgetPress(access: ShortcutAccess.paid, hasPattern: false);
    expect(empty.records, isFalse);
    expect(empty.opensPaywall, isFalse);
    expect(empty.result, 'unassigned');
  });

  test('siri asks only after the paid check', () {
    for (final blocked in [
      ShortcutAccess.unpaid,
      ShortcutAccess.expired,
      ShortcutAccess.refunded,
    ]) {
      final start = startSiriLog(blocked);
      expect(start.asks, isFalse);
      expect(start.records, isFalse);
      expect(start.opensPaywall, isTrue);
      expect(start.speech, shortcutPlusSpeech);
      expect(start.entryPoint, 'siri');
      expect(start.stopReason, shortcutStopReason(blocked));
    }

    final paid = startSiriLog(ShortcutAccess.paid);
    expect(paid.asks, isTrue);
    expect(paid.records, isTrue);
    expect(paid.opensPaywall, isFalse);
    expect(paid.speech, isNull);
  });

  test('registrar writes a meal only while access is paid', () {
    final button = LockScreenMealButtonSnapshot(
      slot: 0,
      label: '朝',
      templateId: 'pattern-1',
      items: [
        MealTemplateItem(
          itemId: 'rice',
          name: 'ご飯',
          baseAmount: 100,
          unitType: FoodUnitType.g,
          kcalPerBase: 168,
          consumedAmount: 150,
          sortOrder: 1,
          snapshotSavedAt: now,
        ),
      ],
    );

    LockScreenMealRegisterResult press(ShortcutAccess resolved) {
      return LockScreenMealRegistrar.register(
        paid: false,
        access: resolved,
        button: button,
        ownerUserId: 'member-1',
        loggedAt: now,
        newId: () => 'id',
      );
    }

    for (final blocked in [
      ShortcutAccess.unpaid,
      ShortcutAccess.expired,
      ShortcutAccess.refunded,
    ]) {
      final result = press(blocked);
      expect(result.meal, isNull);
      expect(result.status.name, shortcutAnalyticsResult(blocked));
    }

    final paid = press(ShortcutAccess.paid);
    expect(paid.status, LockScreenMealRegisterStatus.registered);
    expect(paid.meal, isNotNull);
  });

  test('gallery copy and the locked face live in the widget', () {
    final widget = File(
      'ios/LockScreenMealWidget/LockScreenMealWidget.swift',
    ).readAsStringSync();
    expect(widget, contains(widgetHomeGalleryDescription));
    expect(widget, contains(widgetLockGalleryDescription));
    expect(widget, contains('lock.fill'));
    expect(widget, contains('カロナビ+'));
    expect(widget, contains('OpenCalonaviPlusIntent'));
    expect(widget, contains('readGrant().expiresAt'));
    expect(widget, contains('WidgetTimelinePlan.dates'));
    final timeline = widget.substring(
      widget.indexOf('static func timeline('),
      widget.indexOf('struct HomeMealWidget'),
    );
    expect(timeline, contains('WidgetTimelinePlan.refreshAt'));
    expect(timeline, contains('policy = .after(refresh)'));
    expect(timeline, contains('policy: policy'));
    expect(timeline, isNot(contains('reload')));
    var timelineSearch = 0;
    var timelineProviders = 0;
    while (true) {
      final start = widget.indexOf('func getTimeline(', timelineSearch);
      if (start < 0) {
        break;
      }
      final end = widget.indexOf('\n  }', start);
      final body = widget.substring(start, end);
      expect(body, contains('PlusStoreProbe.live()'));
      expect(body, isNot(contains('reload')));
      timelineProviders += 1;
      timelineSearch = end + 1;
    }
    expect(timelineProviders, 2);
    expect('Text("タップで記録")'.allMatches(widget), hasLength(1));
    expect(widget, contains('static var openAppWhenRun = true'));
    final lockedFace = widget.indexOf('struct LockedMealFace');
    final lockedBody = widget.substring(
      lockedFace,
      widget.indexOf('struct ', lockedFace + 1),
    );
    expect(lockedBody, contains('lock.fill'));
    expect(lockedBody, contains('カロナビ+'));
    expect(lockedBody, isNot(contains('figures')));
    expect(lockedBody, isNot(contains('kcal')));

    final siri = File('ios/Runner/SiriVoiceLog.swift').readAsStringSync();
    final foodGate = siri.indexOf(
      'SiriPlusGate.evaluate(intent: "log_food"',
    );
    final foodAsk = siri.indexOf('promptedFoodName()');
    expect(foodGate, greaterThanOrEqualTo(0));
    expect(foodAsk, greaterThan(foodGate));
    expect(
      siri.indexOf('SiriPlusGate.evaluate('),
      lessThan(siri.indexOf('promptedActivityName()')),
    );
    expect(siri, isNot(contains('requestValueDialog')));
    expect(siri.indexOf('let question = "何を食べましたか？"'), greaterThan(foodGate));
    expect(
      siri.indexOf('let question = "何をしましたか？"'),
      greaterThan(siri.indexOf('intent: "log_exercise"')),
    );
    final commit = siri.indexOf('static func commitStep');
    final commitBody = siri.substring(
      commit,
      siri.indexOf('static func commitConfirmed'),
    );
    expect(commitBody.indexOf('plusBlockedNow()'), greaterThanOrEqualTo(0));
    expect(
      commitBody.indexOf('plusBlockedNow()'),
      lessThan(commitBody.indexOf('commitAll(plan.records)')),
    );
    final probe = siri.indexOf('static func plusBlockedNow');
    expect(
      siri.indexOf('PlusStoreProbe.live()', probe),
      lessThan(siri.indexOf('allowsRegister', probe)),
    );
    expect(siri, contains('intent: "log_utterance"'));
    expect(siri, contains('intent: "undo"'));
    final entryIntent = siri.indexOf('struct LogSpokenEntryIntent');
    final entryBody = siri.substring(
      entryIntent,
      siri.indexOf('struct SiriChoiceEntity'),
    );
    expect(entryBody, contains('var utterance: SiriSpokenText?'));
    expect(entryBody, isNot(contains('var utterance: SiriSpokenText\n')));
    expect(entryBody, contains('self.utterance = nil'));
    expect(entryBody, isNot(contains(r'$utterance')));
    final utteranceGate = entryBody.indexOf('intent: "log_utterance"');
    expect(entryBody.indexOf('routedEntry()'), greaterThan(utteranceGate));
    expect(
      entryBody.indexOf(r'$entryReply.requestValue'),
      greaterThan(utteranceGate),
    );
    expect(
      entryBody.indexOf('let question = "食事ですか、運動ですか？"'),
      greaterThan(utteranceGate),
    );

    final project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final testsPhase = project.indexOf(
      '2CAFBE392D4E13294813B049 /* Frameworks */',
    );
    final testsFiles = project.substring(
      testsPhase,
      project.indexOf('runOnlyForDeploymentPostprocessing', testsPhase),
    );
    expect(testsFiles, contains('WidgetKit.framework in Frameworks'));

    final store = File(
      'ios/LockScreenMeal/LockScreenMealStore.swift',
    ).readAsStringSync();
    expect(store, isNot(contains('source: "preview", expiresAt: nil')));
    expect(store, contains('static func roundedKcal'));
    expect(
      store,
      contains('static let paidRefreshInterval: TimeInterval = TimeInterval(15 * 60)'),
    );
    expect(store, contains('guard access == .paid'));
    expect(store, isNot(contains('reloadAfterRevocation')));
    expect(store, isNot(contains('revocationReloadAt')));
  });

  test('grant channel keeps the old paid payload and adds source', () async {
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];
    const channel = MethodChannel(lockScreenMealMethodChannel);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'takePlusEntry') {
            return 'siri';
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final gateway = LockScreenMealGatewayImpl(
      preferences: await SharedPreferences.getInstance(),
      channel: channel,
    );

    await gateway.setShortcutGrant(ShortcutGrant.store(future));
    expect(calls.single.method, 'setPaid');
    expect(calls.single.arguments, {
      'paid': true,
      'source': 'store',
      'expiresAt': future.toUtc().toIso8601String(),
    });

    calls.clear();
    await gateway.setPaid(true);
    expect(calls.single.arguments, {'paid': true});
    expect(await gateway.takeShortcutPlusEntry(), 'siri');
  });

  testWidgets('widget opens the existing paywall', (tester) async {
    await _openShortcutPaywall(tester, 'widget');
  });

  testWidgets('siri opens the existing paywall', (tester) async {
    await _openShortcutPaywall(tester, 'siri');
  });

  test('the app writes complimentary, store, revoked, and logout grants', () async {
    final gateway = _GrantGateway();
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'member-1', email: 'member@example.test'),
    );
    final complimentary = AppController(
      authenticationRepository: auth,
      lockScreenMealGateway: gateway,
      subscriptionRepository: _InactivePlus(),
      complimentaryPlus: _AlwaysComplimentary(),
    );
    await complimentary.refreshPaidEntitlement();
    expect(gateway.grants.last.source, ShortcutGrantSource.complimentary);
    expect(gateway.paid, isTrue);
    await complimentary.setLockScreenMealPaid(false);
    expect(gateway.grants.last.source, ShortcutGrantSource.none);
    expect(gateway.paid, isFalse);
    complimentary.dispose();

    final active = _InactivePlus()..active = true;
    final local = AppController(
      lockScreenMealGateway: gateway,
      subscriptionRepository: active,
    );
    await local.refreshPaidEntitlement();
    expect(gateway.grants.last.source, ShortcutGrantSource.preview);
    expect(gateway.paid, isTrue);
    local.dispose();

    final serverGateway = _GrantGateway();
    final serverAuth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'member-2', email: 'member2@example.test'),
    );
    final futureUsage = _FixedUsage(
      StoreEntitlementVerification(
        outcome: StoreVerifyOutcome.accepted,
        plus: true,
        expiresAt: future,
      ),
    );
    final server = AppController(
      authenticationRepository: serverAuth,
      lockScreenMealGateway: serverGateway,
      subscriptionRepository: _InactivePlus(),
      usageRecordRepository: futureUsage,
      serverPlusStore: ServerPlusStore.memory(),
    );
    expect(await server.ensurePaidShortcutsReady(), isTrue);
    expect(serverGateway.grants.last.source, ShortcutGrantSource.store);
    expect(serverGateway.grants.last.expiresAt, future);
    expect(serverGateway.paid, isTrue);
    server.dispose();

    final expiredGateway = _GrantGateway();
    final expired = AppController(
      authenticationRepository: MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'member-3', email: 'member3@example.test'),
      ),
      lockScreenMealGateway: expiredGateway,
      subscriptionRepository: _InactivePlus(),
      usageRecordRepository: _FixedUsage(
        StoreEntitlementVerification(
          outcome: StoreVerifyOutcome.accepted,
          plus: true,
          expiresAt: past,
        ),
      ),
      serverPlusStore: ServerPlusStore.memory(),
    );
    expect(await expired.ensurePaidShortcutsReady(), isFalse);
    expect(expiredGateway.grants.last.source, ShortcutGrantSource.store);
    expect(expiredGateway.grants.last.expiresAt, past);
    expect(expiredGateway.paid, isFalse);
    expired.dispose();

    final revokedGateway = _GrantGateway();
    final revoked = AppController(
      authenticationRepository: MockAuthenticationRepository(
        currentUser: const AuthUser(id: 'member-4', email: 'member4@example.test'),
      ),
      lockScreenMealGateway: revokedGateway,
      subscriptionRepository: _RevokedPlus(),
      usageRecordRepository: _FixedUsage(
        StoreEntitlementVerification(
          outcome: StoreVerifyOutcome.accepted,
          plus: true,
          expiresAt: future,
        ),
      ),
      serverPlusStore: ServerPlusStore.memory(),
    );
    expect(await revoked.ensurePaidShortcutsReady(), isFalse);
    expect(revokedGateway.grants.last.source, ShortcutGrantSource.revoked);
    expect(revokedGateway.paid, isFalse);
    revoked.dispose();

    await auth.dispose();
    await serverAuth.dispose();
  });
}

Future<void> _openShortcutPaywall(WidgetTester tester, String entryPoint) async {
  final events = <(String, Map<String, Object?>)>[];
  Analytics.onEmitForTest = (name, props) => events.add((name, props));
  addTearDown(() => Analytics.onEmitForTest = null);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Builder(
        builder: (context) {
          return TextButton(
            onPressed: () => presentShortcutPlus(
              context,
              entryPoint: entryPoint,
              repository: _PricedPlus(),
            ),
            child: Text(entryPoint),
          );
        },
      ),
    ),
  );
  await tester.tap(find.text(entryPoint));
  await tester.pumpAndSettle();
  expect(
    events.where(
      (event) =>
          event.$1 == 'gate_shown' &&
          event.$2['feature'] == entryPoint &&
          event.$2['entry_point'] == entryPoint,
    ),
    hasLength(1),
  );
  expect(
    events.where(
      (event) =>
          event.$1 == 'paywall_open' && event.$2['entry_point'] == entryPoint,
    ),
    isNotEmpty,
  );
  expect(find.textContaining('¥980'), findsWidgets);
}

class _AlwaysComplimentary implements ComplimentaryPlusRepository {
  @override
  Future<bool?> current() async => true;
}

class _InactivePlus extends UnavailableSubscriptionRepository {
  bool active = false;

  @override
  bool get isPlusActive => active;
}

class _RevokedPlus extends UnavailableSubscriptionRepository {
  @override
  bool get isPlusActive => false;

  @override
  List<SubscriptionEntitlementRecord> get inactiveEntitlements => const [
    SubscriptionEntitlementRecord(
      productId: SubscriptionCatalog.monthlyProductId,
      expiresAt: null,
      revoked: true,
    ),
  ];
}

class _FixedUsage extends NoOpUsageRecordRepository {
  _FixedUsage(this.verification);

  final StoreEntitlementVerification verification;

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

class _PricedPlus extends UnavailableSubscriptionRepository {
  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return const SubscriptionOfferings(
      monthly: SubscriptionProductOffer(
        productId: SubscriptionCatalog.monthlyProductId,
        period: PlusBillingPeriod.month,
        localizedPrice: '¥980',
      ),
      yearly: null,
      loadFailed: false,
    );
  }
}

class _GrantGateway with LockScreenGrantFallback implements LockScreenMealGateway {
  bool paid = false;
  final List<ShortcutGrant> grants = [];

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
  }

  @override
  Future<void> setShortcutGrant(ShortcutGrant grant) async {
    grants.add(grant);
    paid = grant.allows;
  }
}
