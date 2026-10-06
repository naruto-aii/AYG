import 'dart:io';

import 'package:ayg/config/development_plus_preview.dart';
import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/config/test_purchase.dart';
import 'package:ayg/constants/app_strings.dart';
import 'package:ayg/repositories/authentication_repository.dart';
import 'package:ayg/repositories/storekit_subscription_repository.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/repositories/usage_record_repository.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/screens/subscription/calonavi_plus_flow.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/services/lock_screen_meal_gateway.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_authentication_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 10, 6, 9);

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  Future<StoreKitSubscriptionRepository> openRepository({
    required SharedPreferences preferences,
    bool testPurchaseEnabled = false,
    bool authoritative = false,
  }) async {
    final repository = StoreKitSubscriptionRepository(
      preferences: preferences,
      purchaseUpdates: const Stream.empty(),
      loadEntitlements: () async =>
          EntitlementLoad(records: const [], authoritative: authoritative),
      clock: () => now,
      testPurchaseEnabled: testPurchaseEnabled,
    );
    await repository.initialize();
    return repository;
  }

  test('archive builds leave the test purchase flag off', () {
    expect(testPurchaseEnabled, isFalse);
    expect(developmentPlusPreview, isTrue);

    final script = File('tool/run_ios.sh').readAsStringSync();
    expect(script, contains('--dart-define=CALONAVI_TEST_PURCHASE=true'));
    expect('TEST_PURCHASE_DEFINE'.allMatches(script).length, 3);

    const storeBuildFiles = [
      'ios/Flutter/Debug.xcconfig',
      'ios/Flutter/Profile.xcconfig',
      'ios/Flutter/Release.xcconfig',
      'ios/Flutter/enable_official_foods_define.sh',
      'ios/Runner.xcodeproj/project.pbxproj',
    ];
    for (final path in storeBuildFiles) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('CALONAVI_TEST_PURCHASE')),
        reason: path,
      );
    }

    final migration = File(
      'supabase/migrations/20261006140000_calonavi_plus_test_product.sql',
    ).readAsStringSync();
    expect(migration, contains('calonavi_plus_test'));
    expect(migration, contains('calonavi_plus_monthly'));
    expect(migration, contains('calonavi_plus_yearly'));
    expect(migration, isNot(contains('create table')));
    expect(
      migration.toLowerCase(),
      isNot(contains('disable row level security')),
    );
    expect(
      SubscriptionCatalog.plusProductIds,
      isNot(contains(SubscriptionCatalog.testPurchaseProductId)),
    );
    expect(
      SubscriptionCatalog.syncsEntitlement(
        SubscriptionCatalog.testPurchaseProductId,
      ),
      isTrue,
    );

    final halfYear = File(
      'supabase/migrations/20261006150000_calonavi_plus_half_year_product.sql',
    ).readAsStringSync();
    expect(halfYear, contains('calonavi_plus_half_year'));
    expect(halfYear, contains('calonavi_plus_monthly'));
    expect(halfYear, contains('calonavi_plus_yearly'));
    expect(halfYear, contains('calonavi_plus_test'));
    expect(halfYear, isNot(contains('create table')));
    expect(
      halfYear.toLowerCase(),
      isNot(contains('disable row level security')),
    );
  });

  test(
    'the purchase button grants plus without touching the store cache',
    () async {
      final prefs = await prefsWith({});
      final repository = await openRepository(
        preferences: prefs,
        testPurchaseEnabled: true,
        authoritative: true,
      );
      final synced = <bool>[];
      final sub = repository.entitlementChanges.listen((_) {
        synced.add(repository.entitlementAuthoritative);
      });

      expect(repository.isPlusActive, isFalse);
      expect(
        prefs.getString(StoreKitSubscriptionRepository.entitlementsKey),
        '[]',
      );

      await repository.purchasePlan(PlusPlan.monthly);
      await Future<void>.delayed(Duration.zero);

      expect(repository.isPlusActive, isTrue);
      expect(repository.testPurchaseToggleEnabled, isTrue);
      expect(prefs.getBool(StoreKitSubscriptionRepository.testPlusKey), isTrue);
      expect(prefs.getInt(StoreKitSubscriptionRepository.expiryKey), isNull);
      expect(
        prefs.getString(StoreKitSubscriptionRepository.entitlementsKey),
        '[]',
      );
      expect(
        repository.confirmedEntitlements.map((record) => record.productId),
        [SubscriptionCatalog.testPurchaseProductId],
      );
      expect(synced, [false]);

      final restored = await openRepository(
        preferences: prefs,
        testPurchaseEnabled: true,
      );
      expect(restored.isPlusActive, isTrue);

      await repository.clearTestPurchase();
      expect(repository.isPlusActive, isFalse);
      expect(
        prefs.getBool(StoreKitSubscriptionRepository.testPlusKey),
        isFalse,
      );
      expect(
        repository.inactiveEntitlements.single.productId,
        SubscriptionCatalog.testPurchaseProductId,
      );
      expect(
        prefs.getString(StoreKitSubscriptionRepository.entitlementsKey),
        '[]',
      );

      await sub.cancel();
      await repository.dispose();
      await restored.dispose();
    },
  );

  test('clearing the test override keeps a real store expiry', () async {
    final expiry = now.add(const Duration(days: 3));
    final prefs = await prefsWith({
      StoreKitSubscriptionRepository.expiryKey: expiry.millisecondsSinceEpoch,
    });
    final repository = await openRepository(
      preferences: prefs,
      testPurchaseEnabled: true,
    );

    expect(repository.isPlusActive, isTrue);
    await repository.purchasePlan(PlusPlan.yearly);
    await repository.clearTestPurchase();

    expect(repository.isPlusActive, isTrue);
    expect(
      prefs.getInt(StoreKitSubscriptionRepository.expiryKey),
      expiry.millisecondsSinceEpoch,
    );
    expect(prefs.getBool(StoreKitSubscriptionRepository.testPlusKey), isFalse);

    await repository.dispose();
  });

  test(
    'without the flag, a stored test override does not grant plus',
    () async {
      final prefs = await prefsWith({
        StoreKitSubscriptionRepository.testPlusKey: true,
      });
      final repository = await openRepository(
        preferences: prefs,
        testPurchaseEnabled: false,
      );

      expect(repository.isPlusActive, isFalse);
      expect(repository.confirmedEntitlements, isEmpty);
      await repository.clearTestPurchase();
      expect(prefs.getBool(StoreKitSubscriptionRepository.testPlusKey), isTrue);

      await repository.dispose();
    },
  );

  test(
    'plus and free update the widget flag and the supabase payload',
    () async {
      final prefs = await prefsWith({});
      final repository = await openRepository(
        preferences: prefs,
        testPurchaseEnabled: true,
        authoritative: true,
      );
      final gateway = _FlagGateway();
      final usage = _RecordingUsage();
      final controller = AppController(
        authenticationRepository: MockAuthenticationRepository(
          currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
        ),
        lockScreenMealGateway: gateway,
        subscriptionRepository: repository,
        usageRecordRepository: usage,
      );

      await controller.initialize();
      expect(gateway.paid, isFalse);

      await repository.purchasePlan(PlusPlan.yearly);
      await Future<void>.delayed(Duration.zero);

      expect(controller.subscriptionRepository.isPlusActive, isTrue);
      expect(gateway.paid, isTrue);
      expect(usage.calls.single.authoritative, isFalse);
      expect(
        usage.calls.single.confirmed.single.productId,
        SubscriptionCatalog.testPurchaseProductId,
      );
      expect(usage.calls.single.inactive, isEmpty);

      await repository.clearTestPurchase();
      await Future<void>.delayed(Duration.zero);

      expect(controller.subscriptionRepository.isPlusActive, isFalse);
      expect(gateway.paid, isFalse);
      expect(usage.calls.last.authoritative, isFalse);
      expect(usage.calls.last.confirmed, isEmpty);
      expect(
        usage.calls.last.inactive.single.productId,
        SubscriptionCatalog.testPurchaseProductId,
      );

      controller.dispose();
      await repository.dispose();
    },
  );

  testWidgets('settings shows the free button only in a test build', (
    tester,
  ) async {
    final hidden = _ToggleRepo(enabled: false);
    final auth = MockAuthenticationRepository(
      currentUser: const AuthUser(id: 'user-1', email: 'a@example.com'),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: AppController(
            authenticationRepository: auth,
            subscriptionRepository: hidden,
          ),
          authenticationRepository: auth,
          hideHealthSettings: true,
        ),
      ),
    );
    expect(find.byKey(const Key('test-purchase-revert')), findsNothing);

    final shown = _ToggleRepo(enabled: true, active: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: SettingsScreen(
          controller: AppController(
            authenticationRepository: auth,
            subscriptionRepository: shown,
          ),
          authenticationRepository: auth,
          hideHealthSettings: true,
        ),
      ),
    );
    expect(find.text('テスト用: 無料に戻す'), findsOneWidget);
    expect(find.text('今はカロナビ+です。押すとすぐに無料になります'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('test-purchase-revert')));
    await tester.tap(find.byKey(const Key('test-purchase-revert')));
    await tester.pump();
    expect(shown.clears, 1);
    expect(find.text('無料に戻しました'), findsOneWidget);
  });

  testWidgets('the paywall purchase button skips the store in a test build', (
    tester,
  ) async {
    final repository = _ImmediatePlus();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: CalonaviPlusEntryScreen(repository: repository),
      ),
    );
    await tester.pump();

    expect(repository.offeringLoads, 0);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('${AppStrings.plusFallbackYearlyPrice}で始める'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('plus-purchase')));
    await tester.pump();

    expect(repository.purchases, 1);
    expect(repository.isPlusActive, isTrue);
    expect(find.text('テスト用にカロナビ+にしました'), findsOneWidget);
  });
}

class _FlagGateway implements LockScreenMealGateway {
  bool paid = false;

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
}

class _RecordingUsage extends NoOpUsageRecordRepository {
  final calls = <_SyncCall>[];

  @override
  Future<void> syncPlusEntitlements({
    required List<SubscriptionEntitlementRecord> confirmed,
    required List<SubscriptionEntitlementRecord> inactive,
    required bool authoritative,
    DateTime? now,
  }) async {
    calls.add(
      _SyncCall(
        confirmed: confirmed,
        inactive: inactive,
        authoritative: authoritative,
      ),
    );
  }
}

class _SyncCall {
  const _SyncCall({
    required this.confirmed,
    required this.inactive,
    required this.authoritative,
  });

  final List<SubscriptionEntitlementRecord> confirmed;
  final List<SubscriptionEntitlementRecord> inactive;
  final bool authoritative;
}

class _ImmediatePlus extends UnavailableSubscriptionRepository {
  int purchases = 0;
  int offeringLoads = 0;
  bool active = false;

  @override
  bool get testPurchaseToggleEnabled => true;

  @override
  bool get isPlusActive => active;

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    offeringLoads += 1;
    return SubscriptionOfferings.failed;
  }

  @override
  Future<void> purchasePlan(PlusPlan plan) async {
    purchases += 1;
    active = true;
  }
}

class _ToggleRepo extends UnavailableSubscriptionRepository {
  _ToggleRepo({required this.enabled, this.active = false});

  final bool enabled;
  bool active;
  int clears = 0;

  @override
  bool get testPurchaseToggleEnabled => enabled;

  @override
  bool get isPlusActive => active;

  @override
  Future<void> clearTestPurchase() async {
    clears += 1;
    active = false;
  }
}
