import 'dart:async';

import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/storekit_subscription_repository.dart';
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
  }) {
    return SK2PurchaseDetails(
      productID: productId,
      purchaseID: 'tx-$productId',
      verificationData: PurchaseVerificationData(
        localVerificationData: 'local',
        serverVerificationData: 'server',
        source: 'app_store',
      ),
      transactionDate: '${now.millisecondsSinceEpoch}',
      status: PurchaseStatus.purchased,
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
}
