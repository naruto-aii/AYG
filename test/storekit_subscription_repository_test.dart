import 'dart:async';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/storekit_subscription_repository.dart';
import 'package:ayg/repositories/subscription_exceptions.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 9, 27, 9);

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  SK2PurchaseDetails purchase({
    required String productId,
    String? expirationDate,
    String localVerificationData = 'local',
    String serverVerificationData = 'server',
    PurchaseStatus status = PurchaseStatus.purchased,
  }) {
    return SK2PurchaseDetails(
      productID: productId,
      purchaseID: 'tx-$productId',
      verificationData: PurchaseVerificationData(
        localVerificationData: localVerificationData,
        serverVerificationData: serverVerificationData,
        source: 'app_store',
      ),
      transactionDate: '${now.millisecondsSinceEpoch}',
      status: status,
      expirationDate: expirationDate,
    );
  }

  test(
    'legacy active flag does not keep plus without a future expiry',
    () async {
      final prefs = await prefsWith({
        StoreKitSubscriptionRepository.legacyPlusKey: true,
      });
      final repository = StoreKitSubscriptionRepository(
        preferences: prefs,
        purchaseUpdates: const Stream.empty(),
        loadEntitlements: () async =>
            const EntitlementLoad(records: [], authoritative: true),
        clock: () => now,
      );

      await repository.initialize();

      expect(repository.isPlusActive, isFalse);
      expect(
        prefs.getBool(StoreKitSubscriptionRepository.legacyPlusKey),
        isNull,
      );
      expect(prefs.getInt(StoreKitSubscriptionRepository.expiryKey), isNull);
      await repository.dispose();
    },
  );

  test('a store failure keeps a still-future cached expiry', () async {
    final future = now.add(const Duration(days: 12));
    final prefs = await prefsWith({
      StoreKitSubscriptionRepository.legacyPlusKey: true,
      StoreKitSubscriptionRepository.expiryKey: future.millisecondsSinceEpoch,
    });
    final repository = StoreKitSubscriptionRepository(
      preferences: prefs,
      purchaseUpdates: const Stream.empty(),
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: false),
      clock: () => now,
    );

    await repository.initialize();

    expect(repository.isPlusActive, isTrue);
    expect(prefs.getBool(StoreKitSubscriptionRepository.legacyPlusKey), isNull);
    expect(
      prefs.getInt(StoreKitSubscriptionRepository.expiryKey),
      future.millisecondsSinceEpoch,
    );
    expect(repository.confirmedEntitlements, isEmpty);
    expect(
      prefs.getString(StoreKitSubscriptionRepository.entitlementsKey),
      isNull,
    );
    await repository.dispose();
  });

  test('an authoritative expiry replaces the cached flag', () async {
    final future = now.add(const Duration(days: 20));
    final expired = now.subtract(const Duration(hours: 2));
    final prefs = await prefsWith({
      StoreKitSubscriptionRepository.expiryKey: future.millisecondsSinceEpoch,
    });
    final repository = StoreKitSubscriptionRepository(
      preferences: prefs,
      purchaseUpdates: const Stream.empty(),
      loadEntitlements: () async => EntitlementLoad(
        records: [
          SubscriptionEntitlementRecord(
            productId: SubscriptionCatalog.yearlyProductId,
            expiresAt: expired,
          ),
        ],
        authoritative: true,
      ),
      clock: () => now,
    );

    await repository.initialize();

    expect(repository.isPlusActive, isFalse);
    expect(
      prefs.getInt(StoreKitSubscriptionRepository.expiryKey),
      expired.millisecondsSinceEpoch,
    );
    expect(repository.confirmedEntitlements, hasLength(1));
    expect(
      repository.confirmedEntitlements.single.productId,
      SubscriptionCatalog.yearlyProductId,
    );
    final stored = prefs.getString(
      StoreKitSubscriptionRepository.entitlementsKey,
    );
    expect(stored, contains(SubscriptionCatalog.yearlyProductId));
    expect(stored, isNot(contains('verification')));
    expect(stored, isNot(contains('token')));
    expect(stored, isNot(contains('receipt')));
    await repository.dispose();
  });

  test('refresh keeps the latest expiry when an older transaction is read last', () async {
    final later = now.add(const Duration(days: 40));
    final earlier = now.add(const Duration(days: 10));
    final repository = StoreKitSubscriptionRepository(
      preferences: await prefsWith({}),
      purchaseUpdates: const Stream.empty(),
      loadEntitlements: () async => EntitlementLoad(
        records: [
          SubscriptionEntitlementRecord(
            productId: SubscriptionCatalog.monthlyProductId,
            expiresAt: later,
            signedTransaction: 'later.payload.signature',
          ),
          SubscriptionEntitlementRecord(
            productId: SubscriptionCatalog.monthlyProductId,
            expiresAt: earlier,
            signedTransaction: 'earlier.payload.signature',
          ),
          SubscriptionEntitlementRecord(
            productId: SubscriptionCatalog.monthlyProductId,
            expiresAt: later.add(const Duration(days: 5)),
            signedTransaction: 'revoked.payload.signature',
            revoked: true,
          ),
        ],
        authoritative: true,
      ),
      clock: () => now,
    );
    await repository.initialize();
    expect(repository.isPlusActive, isTrue);
    expect(
      repository.confirmedEntitlements.single.signedTransaction,
      'later.payload.signature',
    );
    expect(
      repository.inactiveEntitlements.map((record) => record.signedTransaction),
      isNot(contains('revoked.payload.signature')),
    );
    await repository.dispose();
  });

  test('an older purchase update does not replace a newer signed transaction', () async {
    final prefs = await prefsWith({});
    final updates = StreamController<List<PurchaseDetails>>();
    final repository = StoreKitSubscriptionRepository(
      preferences: prefs,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: false),
      clock: () => now,
    );
    await repository.initialize();
    final later = now.add(const Duration(days: 40));
    final earlier = now.add(const Duration(days: 10));
    updates.add([
      purchase(
        productId: SubscriptionCatalog.monthlyProductId,
        expirationDate: '${later.millisecondsSinceEpoch}',
        serverVerificationData: 'later.payload.signature',
      ),
    ]);
    await repository.plusChanges.first.timeout(const Duration(seconds: 2));
    updates.add([
      purchase(
        productId: SubscriptionCatalog.monthlyProductId,
        expirationDate: '${earlier.millisecondsSinceEpoch}',
        serverVerificationData: 'earlier.payload.signature',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(
      repository.confirmedEntitlements.single.signedTransaction,
      'later.payload.signature',
    );
    expect(
      repository.confirmedEntitlements.single.expiresAt?.isAtSameMomentAs(later),
      isTrue,
    );
    await updates.close();
    await repository.dispose();
  });

  test('purchase and restore keep Plus locally and hold the signed transaction', () async {
    final prefs = await prefsWith({});
    final updates = StreamController<List<PurchaseDetails>>();
    final repository = StoreKitSubscriptionRepository(
      preferences: prefs,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: false),
      clock: () => now,
    );
    await repository.initialize();
    const signed = 'header.payload.signature';
    final expiry = now.add(const Duration(days: 30));
    updates.add([
      purchase(
        productId: SubscriptionCatalog.monthlyProductId,
        expirationDate: '${expiry.millisecondsSinceEpoch}',
        serverVerificationData: signed,
      ),
    ]);
    await repository.plusChanges.first.timeout(const Duration(seconds: 2));
    expect(repository.isPlusActive, isTrue);
    expect(
      repository.confirmedEntitlements.single.signedTransaction,
      signed,
    );
    expect(prefs.getString(StoreKitSubscriptionRepository.entitlementsKey), isNot(contains(signed)));

    updates.add([
      purchase(
        productId: SubscriptionCatalog.yearlyProductId,
        expirationDate: '${expiry.millisecondsSinceEpoch}',
        serverVerificationData: 'restore.payload.signature',
        status: PurchaseStatus.restored,
      ),
    ]);
    await repository.entitlementChanges.first.timeout(const Duration(seconds: 2));
    expect(repository.isPlusActive, isTrue);
    expect(
      repository.confirmedEntitlements.map((record) => record.signedTransaction),
      contains('restore.payload.signature'),
    );
    await updates.close();
    await repository.dispose();
  });

  test(
    'purchase expiry turns plus on and a missing expiry turns it off',
    () async {
      final prefs = await prefsWith({});
      final updates = StreamController<List<PurchaseDetails>>();
      var expired = false;
      final repository = StoreKitSubscriptionRepository(
        preferences: prefs,
        purchaseUpdates: updates.stream,
        loadEntitlements: () async {
          if (!expired) {
            return const EntitlementLoad(records: [], authoritative: false);
          }
          return EntitlementLoad(
            records: [
              SubscriptionEntitlementRecord(
                productId: SubscriptionCatalog.monthlyProductId,
                expiresAt: now.subtract(const Duration(days: 1)),
              ),
            ],
            authoritative: true,
          );
        },
        clock: () => now,
      );
      await repository.initialize();
      expect(repository.isPlusActive, isFalse);

      final expiry = now.add(const Duration(days: 30));
      final becamePlus = repository.plusChanges.first;
      updates.add([
        purchase(
          productId: SubscriptionCatalog.monthlyProductId,
          expirationDate: '${expiry.millisecondsSinceEpoch}',
        ),
      ]);
      expect(await becamePlus.timeout(const Duration(seconds: 2)), isTrue);
      expect(
        prefs.getInt(StoreKitSubscriptionRepository.expiryKey),
        expiry.millisecondsSinceEpoch,
      );

      final lostPlus = repository.plusChanges.first;
      updates.add([
        purchase(
          productId: SubscriptionCatalog.monthlyProductId,
          expirationDate: null,
        ),
      ]);
      expect(await lostPlus.timeout(const Duration(seconds: 2)), isFalse);
      expect(prefs.getInt(StoreKitSubscriptionRepository.expiryKey), isNull);

      expired = true;
      updates.add([
        purchase(
          productId: SubscriptionCatalog.yearlyProductId,
          expirationDate: '${expiry.millisecondsSinceEpoch}',
        ),
      ]);
      await repository.plusChanges.first.timeout(const Duration(seconds: 2));
      await repository.initialize();
      expect(repository.isPlusActive, isFalse);

      await updates.close();
      await repository.dispose();
    },
  );

  test('a revoked transaction does not grant plus', () async {
    final prefs = await prefsWith({});
    final updates = StreamController<List<PurchaseDetails>>();
    final repository = StoreKitSubscriptionRepository(
      preferences: prefs,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: false),
      clock: () => now,
    );
    await repository.initialize();

    final expiry = now.add(const Duration(days: 30));
    updates.add([
      purchase(
        productId: SubscriptionCatalog.monthlyProductId,
        expirationDate: '${expiry.millisecondsSinceEpoch}',
        localVerificationData: '{"revocationDate":1700000000000}',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.isPlusActive, isFalse);

    final becamePlus = repository.plusChanges.first;
    updates.add([
      purchase(
        productId: SubscriptionCatalog.monthlyProductId,
        expirationDate: '${expiry.millisecondsSinceEpoch}',
      ),
    ]);
    expect(await becamePlus.timeout(const Duration(seconds: 2)), isTrue);

    final revoked = repository.plusChanges.first;
    updates.add([
      purchase(
        productId: SubscriptionCatalog.monthlyProductId,
        expirationDate: '${expiry.millisecondsSinceEpoch}',
        localVerificationData: '{"revocationDate":"2026-01-01T00:00:00Z"}',
      ),
    ]);
    expect(await revoked.timeout(const Duration(seconds: 2)), isFalse);
    expect(repository.isPlusActive, isFalse);

    await updates.close();
    await repository.dispose();
  });

  test('a longer revoked transaction does not clear a different current period', () async {
    final prefs = await prefsWith({});
    final updates = StreamController<List<PurchaseDetails>>();
    final repository = StoreKitSubscriptionRepository(
      preferences: prefs,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: false),
      clock: () => now,
    );
    await repository.initialize();
    final current = now.add(const Duration(days: 3));
    updates.add([
      purchase(
        productId: SubscriptionCatalog.monthlyProductId,
        expirationDate: '${current.millisecondsSinceEpoch}',
        serverVerificationData: 'current.payload.signature',
      ),
    ]);
    await repository.plusChanges.first.timeout(const Duration(seconds: 2));
    updates.add([
      purchase(
        productId: SubscriptionCatalog.monthlyProductId,
        expirationDate: '${now.add(const Duration(days: 40)).millisecondsSinceEpoch}',
        serverVerificationData: 'revoked.payload.signature',
        localVerificationData: '{"revocationDate":1700000000000}',
      ),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(repository.isPlusActive, isTrue);
    expect(
      repository.confirmedEntitlements.single.signedTransaction,
      'current.payload.signature',
    );
    expect(
      repository.inactiveEntitlements.map((record) => record.signedTransaction),
      isNot(contains('revoked.payload.signature')),
    );

    await updates.close();
    await repository.dispose();
  });

  test('refresh turns plus off after the cached expiry passes', () async {
    final expiry = now.add(const Duration(hours: 1));
    final prefs = await prefsWith({
      StoreKitSubscriptionRepository.expiryKey: expiry.millisecondsSinceEpoch,
    });
    var clock = now;
    final repository = StoreKitSubscriptionRepository(
      preferences: prefs,
      purchaseUpdates: const Stream.empty(),
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: false),
      clock: () => clock,
    );

    await repository.initialize();
    expect(repository.isPlusActive, isTrue);

    clock = expiry.add(const Duration(minutes: 1));
    await repository.refreshEntitlement();
    expect(repository.isPlusActive, isFalse);

    await repository.dispose();
  });

  test(
    'development preview shows plus without a purchase or stored entitlement',
    () async {
      final prefs = await prefsWith({});
      final repository = StoreKitSubscriptionRepository(
        preferences: prefs,
        purchaseUpdates: const Stream.empty(),
        loadEntitlements: () async =>
            const EntitlementLoad(records: [], authoritative: true),
        clock: () => now,
        developmentPlusPreview: true,
      );

      await repository.initialize();

      expect(repository.isPlusActive, isTrue);
      expect(repository.confirmedEntitlements, isEmpty);
      expect(
        prefs.getString(StoreKitSubscriptionRepository.entitlementsKey),
        '[]',
      );
      expect(prefs.getInt(StoreKitSubscriptionRepository.expiryKey), isNull);
      await repository.dispose();
    },
  );

  test('purchasePlan waits until the stream persists the expiry', () async {
    final prefs = await prefsWith({});
    final updates = StreamController<List<PurchaseDetails>>();
    final store = _ScriptedStore(updates)
      ..delay = const Duration(milliseconds: 40);
    final repository = StoreKitSubscriptionRepository(
      purchaseClient: store,
      preferences: prefs,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: false),
      clock: () => now,
    );
    await repository.initialize();

    final done = repository.purchasePlan(PlusPlan.monthly);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(store.buys, 1);
    expect(repository.isPlusActive, isFalse);

    await done.timeout(const Duration(seconds: 2));
    expect(repository.isPlusActive, isTrue);
    expect(
      prefs.getInt(StoreKitSubscriptionRepository.expiryKey),
      DateTime.utc(2026, 10, 27).millisecondsSinceEpoch,
    );

    await updates.close();
    await repository.dispose();
  });

  test('a canceled or failed purchase returns without turning plus on', () async {
    for (final status in [PurchaseStatus.canceled, PurchaseStatus.error]) {
      final prefs = await prefsWith({});
      final updates = StreamController<List<PurchaseDetails>>();
      final store = _ScriptedStore(updates)..status = status;
      final repository = StoreKitSubscriptionRepository(
        purchaseClient: store,
        preferences: prefs,
        purchaseUpdates: updates.stream,
        loadEntitlements: () async =>
            const EntitlementLoad(records: [], authoritative: false),
        clock: () => now,
      );
      await repository.initialize();

      await repository.purchasePlan(PlusPlan.monthly);
      expect(repository.isPlusActive, isFalse);
      expect(prefs.getInt(StoreKitSubscriptionRepository.expiryKey), isNull);

      await updates.close();
      await repository.dispose();
    }
  });

  test('a purchase sheet that does not open does not wait', () async {
    final prefs = await prefsWith({});
    final updates = StreamController<List<PurchaseDetails>>();
    final store = _ScriptedStore(updates)..launch = false;
    final repository = StoreKitSubscriptionRepository(
      purchaseClient: store,
      preferences: prefs,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async =>
          const EntitlementLoad(records: [], authoritative: false),
      clock: () => now,
    );
    await repository.initialize();

    await expectLater(
      repository.purchasePlan(PlusPlan.yearly),
      throwsA(isA<SubscriptionPurchaseFailedException>()),
    );
    expect(repository.isPlusActive, isFalse);

    await updates.close();
    await repository.dispose();
  });

  test('restore fills a missing JWS when the store still says Plus', () async {
    final updates = StreamController<List<PurchaseDetails>>();
    final store = _RestoreStore(updates);
    final expiry = now.add(const Duration(days: 30));
    final repository = StoreKitSubscriptionRepository(
      preferences: await prefsWith({}),
      purchaseClient: store,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async => EntitlementLoad(
        records: [
          SubscriptionEntitlementRecord(
            productId: SubscriptionCatalog.monthlyProductId,
            expiresAt: expiry,
          ),
        ],
        authoritative: true,
      ),
      clock: () => now,
    );
    await repository.initialize();
    expect(repository.isPlusActive, isTrue);
    expect(repository.confirmedEntitlements.single.signedTransaction, isNull);

    await repository.recoverMissingSignedTransactions();

    expect(store.restores, 1);
    expect(
      repository.confirmedEntitlements.single.signedTransaction,
      'header.payload.sig',
    );
    await updates.close();
    await repository.dispose();
  });

  test('a signed entitlement is not restored again', () async {
    final updates = StreamController<List<PurchaseDetails>>();
    final store = _RestoreStore(updates);
    final repository = StoreKitSubscriptionRepository(
      preferences: await prefsWith({}),
      purchaseClient: store,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async => EntitlementLoad(
        records: [
          SubscriptionEntitlementRecord(
            productId: SubscriptionCatalog.monthlyProductId,
            expiresAt: now.add(const Duration(days: 30)),
            signedTransaction: 'already.payload.sig',
          ),
        ],
        authoritative: true,
      ),
      clock: () => now,
    );
    await repository.initialize();
    await repository.recoverMissingSignedTransactions();
    expect(store.restores, 0);
    await updates.close();
    await repository.dispose();
  });

  test('a hung restore does not block JWS recovery', () async {
    final updates = StreamController<List<PurchaseDetails>>();
    final store = _RestoreStore(updates)..hang = true;
    final repository = StoreKitSubscriptionRepository(
      preferences: await prefsWith({}),
      purchaseClient: store,
      purchaseUpdates: updates.stream,
      loadEntitlements: () async => EntitlementLoad(
        records: [
          SubscriptionEntitlementRecord(
            productId: SubscriptionCatalog.monthlyProductId,
            expiresAt: now.add(const Duration(days: 30)),
          ),
        ],
        authoritative: true,
      ),
      clock: () => now,
    );
    await repository.initialize();
    final started = DateTime.now();
    await repository.recoverMissingSignedTransactions(
      timeout: const Duration(milliseconds: 80),
    );
    expect(
      DateTime.now().difference(started),
      lessThan(const Duration(seconds: 2)),
    );
    await updates.close();
    await repository.dispose();
  });
}

class _ScriptedStore implements StorePurchaseClient {
  _ScriptedStore(this.updates);

  final StreamController<List<PurchaseDetails>> updates;
  bool launch = true;
  PurchaseStatus status = PurchaseStatus.purchased;
  Duration delay = Duration.zero;
  int buys = 0;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: [
        ProductDetails(
          id: identifiers.single,
          title: 'カロナビ+',
          description: 'カロナビ+',
          price: '¥980',
          rawPrice: 980,
          currencyCode: 'JPY',
        ),
      ],
      notFoundIDs: const [],
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    buys += 1;
    if (!launch) {
      return false;
    }
    final productId = purchaseParam.productDetails.id;
    Future<void> emit() async {
      updates.add([
        SK2PurchaseDetails(
          productID: productId,
          purchaseID: 'tx',
          verificationData: PurchaseVerificationData(
            localVerificationData: '{}',
            serverVerificationData: '',
            source: 'app_store',
          ),
          transactionDate: '1',
          status: status,
          expirationDate:
              status == PurchaseStatus.purchased ||
                  status == PurchaseStatus.restored
              ? '${DateTime.utc(2026, 10, 27).millisecondsSinceEpoch}'
              : null,
        ),
      ]);
    }
    if (delay == Duration.zero) {
      await emit();
    } else {
      unawaited(Future<void>.delayed(delay, emit));
    }
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {}
}

class _RestoreStore implements StorePurchaseClient {
  _RestoreStore(this.updates);

  final StreamController<List<PurchaseDetails>> updates;
  int restores = 0;
  bool hang = false;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    return ProductDetailsResponse(
      productDetails: const [],
      notFoundIDs: identifiers.toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    return false;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {}

  @override
  Future<void> restorePurchases() async {
    restores += 1;
    if (hang) {
      await Completer<void>().future;
    }
    updates.add([
      SK2PurchaseDetails(
        productID: SubscriptionCatalog.monthlyProductId,
        purchaseID: 'restored',
        verificationData: PurchaseVerificationData(
          localVerificationData: '{}',
          serverVerificationData: 'header.payload.sig',
          source: 'app_store',
        ),
        transactionDate: '1',
        status: PurchaseStatus.restored,
        expirationDate: '${DateTime.utc(2026, 10, 27).millisecondsSinceEpoch}',
      ),
    ]);
  }
}
