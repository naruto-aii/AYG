import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 27, 12);

  test('plus stays active only while the latest expiry is in the future', () {
    final state = SubscriptionEntitlementState();
    state.apply(
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: now.subtract(const Duration(days: 1)),
      ),
    );
    expect(state.isActive(now), isFalse);

    state.apply(
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.yearlyProductId,
        expiresAt: now.add(const Duration(days: 30)),
      ),
    );
    expect(state.isActive(now), isTrue);
    expect(state.latestExpiry, now.add(const Duration(days: 30)));
  });

  test('the current transaction is sent without an older revoked one', () {
    final later = now.add(const Duration(days: 40));
    final earlier = now.add(const Duration(days: 10));
    final selection = selectEntitlementTransactions([
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
    ]);
    expect(selection.active.single.signedTransaction, 'later.payload.signature');
    expect(selection.revocations, isEmpty);
  });

  test('a refund of the current transaction is sent when nothing replaced it', () {
    final expiry = now.add(const Duration(days: 30));
    final selection = selectEntitlementTransactions([
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: expiry,
        signedTransaction: 'revoked.payload.signature',
        revoked: true,
      ),
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: now.add(const Duration(days: 5)),
        signedTransaction: 'older-revoked.payload.signature',
        revoked: true,
      ),
    ]);
    expect(selection.active, isEmpty);
    expect(
      selection.revocations.single.signedTransaction,
      'revoked.payload.signature',
    );
  });

  test('an upgraded transaction is not sent while a current grant exists', () {
    final current = now.add(const Duration(days: 3));
    final selection = selectEntitlementTransactions([
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: current,
        signedTransaction: 'current.payload.signature',
      ),
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: now.add(const Duration(days: 40)),
        signedTransaction: 'upgraded.payload.signature',
        upgraded: true,
      ),
    ]);
    expect(selection.active.single.signedTransaction, 'current.payload.signature');
    expect(selection.revocations, isEmpty);
  });

  test('an upgraded product is sent when that product has no current grant', () {
    final selection = selectEntitlementTransactions([
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: now.add(const Duration(days: 20)),
        signedTransaction: 'upgraded.payload.signature',
        upgraded: true,
      ),
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.yearlyProductId,
        expiresAt: now.add(const Duration(days: 300)),
        signedTransaction: 'yearly.payload.signature',
      ),
    ]);
    expect(selection.active.single.signedTransaction, 'yearly.payload.signature');
    expect(
      selection.revocations.single.signedTransaction,
      'upgraded.payload.signature',
    );
  });

  test('a revocation date blocks the transaction', () {
    expect(parseStoreRevocationDate(null), isNull);
    expect(parseStoreRevocationDate('not json'), isNull);
    expect(parseStoreRevocationDate('{"productId":"x"}'), isNull);

    final millis = parseStoreRevocationDate('{"revocationDate":1700000000000}');
    expect(
      millis,
      DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );

    final seconds = parseStoreRevocationDate('{"revocationDate":1700000000}');
    expect(
      seconds,
      DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true),
    );

    final digits = parseStoreRevocationDate(
      '{"revocationDate":"1700000000000"}',
    );
    expect(digits, millis);

    final iso = parseStoreRevocationDate(
      '{"revocationDate":"2026-01-01T00:00:00Z"}',
    );
    expect(iso, DateTime.utc(2026, 1, 1));
    expect(parseStoreTransactionUpgraded(null), isFalse);
    expect(parseStoreTransactionUpgraded('not json'), isFalse);
    expect(parseStoreTransactionUpgraded('{"isUpgraded":false}'), isFalse);
    expect(parseStoreTransactionUpgraded('{"isUpgraded":true}'), isTrue);
  });

  test('a missing expiry does not keep a product active', () {
    final state = SubscriptionEntitlementState({
      SubscriptionCatalog.monthlyProductId: now.add(const Duration(days: 10)),
    });
    state.apply(
      const SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: null,
      ),
    );
    expect(state.isActive(now), isFalse);
    expect(state.latestExpiry, isNull);
  });

  test('replaceAll keeps the latest expiry when an older one arrives last', () {
    final state = SubscriptionEntitlementState();
    final latest = now.add(const Duration(days: 30));
    final older = now.add(const Duration(days: 1));
    state.replaceAll([
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: latest,
      ),
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: older,
      ),
      const SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: null,
      ),
    ]);
    expect(
      state.expiryByProduct[SubscriptionCatalog.monthlyProductId],
      latest,
    );
    expect(state.isActive(now), isTrue);
  });

  test('replaceAll does not keep an upgraded transaction as Plus', () {
    final state = SubscriptionEntitlementState();
    state.replaceAll([
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: now.add(const Duration(days: 20)),
        upgraded: true,
      ),
    ]);
    expect(state.isActive(now), isFalse);
  });

  test('replaceAll drops products the store no longer returns', () {
    final state = SubscriptionEntitlementState({
      SubscriptionCatalog.monthlyProductId: now.add(const Duration(days: 10)),
      SubscriptionCatalog.yearlyProductId: now.add(const Duration(days: 40)),
    });
    state.replaceAll([
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: now.subtract(const Duration(hours: 1)),
      ),
    ]);
    expect(state.isActive(now), isFalse);
    expect(
      state.expiryByProduct.containsKey(SubscriptionCatalog.yearlyProductId),
      isFalse,
    );
  });

  test('unknown products and unparsable expiry are ignored', () {
    final state = SubscriptionEntitlementState();
    state.apply(
      SubscriptionEntitlementRecord(
        productId: 'some_other_product',
        expiresAt: now.add(const Duration(days: 5)),
      ),
    );
    expect(state.isActive(now), isFalse);
    expect(parseStoreExpiryMillis(null), isNull);
    expect(parseStoreExpiryMillis(''), isNull);
    expect(parseStoreExpiryMillis('not-a-number'), isNull);
    expect(
      parseStoreExpiryMillis('1000'),
      DateTime.fromMillisecondsSinceEpoch(1000),
    );
  });

  test('period labels come from the store period or the product id', () {
    expect(
      periodForProduct(
        productId: SubscriptionCatalog.yearlyProductId,
        storePeriod: PlusBillingPeriod.month,
      ),
      PlusBillingPeriod.month,
    );
    expect(
      periodForProduct(
        productId: SubscriptionCatalog.yearlyProductId,
        storePeriod: PlusBillingPeriod.other,
      ),
      PlusBillingPeriod.year,
    );
    expect(plusPeriodLabel(PlusBillingPeriod.month), '月額');
    expect(plusPeriodLabel(PlusBillingPeriod.year), '年額');
    const offer = SubscriptionProductOffer(
      productId: SubscriptionCatalog.monthlyProductId,
      period: PlusBillingPeriod.month,
      localizedPrice: '¥980',
    );
    expect(offer.canPurchase, isTrue);
    expect(offer.buttonLabel, '月額 ¥980');
    const empty = SubscriptionProductOffer(
      productId: SubscriptionCatalog.monthlyProductId,
      period: PlusBillingPeriod.month,
      localizedPrice: '  ',
    );
    expect(empty.canPurchase, isFalse);
  });

  test('confirmed entitlement json keeps product id and expiry only', () {
    final expiry = DateTime.utc(2026, 10, 3);
    final encoded = encodeConfirmedEntitlements({
      SubscriptionCatalog.yearlyProductId: expiry,
    });
    expect(encoded.contains('receipt'), isFalse);
    expect(encoded.contains('token'), isFalse);
    expect(encoded.contains('verification'), isFalse);
    expect(encoded.contains(SubscriptionCatalog.yearlyProductId), isTrue);

    final decoded = decodeConfirmedEntitlements(
      '[{"productId":"${SubscriptionCatalog.monthlyProductId}","expiresAtMs":${expiry.millisecondsSinceEpoch},"localVerificationData":"secret","purchaseToken":"tok"}]',
    );
    expect(decoded, hasLength(1));
    expect(decoded!.single.productId, SubscriptionCatalog.monthlyProductId);
    expect(
      decoded.single.expiresAt?.millisecondsSinceEpoch,
      expiry.millisecondsSinceEpoch,
    );
    expect(decodeConfirmedEntitlements('[]'), isEmpty);
    expect(decodeConfirmedEntitlements(null), isNull);
  });
}
