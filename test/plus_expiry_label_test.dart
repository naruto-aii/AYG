import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/services/subscription_entitlement.dart';
import 'package:ayg/services/subscription_offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime.utc(2026, 10, 3, 12);

  test('uses the latest future store expiry and ignores unknown dates', () {
    final expiry = latestActivePlusExpiry([
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.monthlyProductId,
        expiresAt: DateTime.utc(2026, 11, 3, 12),
      ),
      SubscriptionEntitlementRecord(
        productId: SubscriptionCatalog.yearlyProductId,
        expiresAt: null,
      ),
      SubscriptionEntitlementRecord(
        productId: 'other_product',
        expiresAt: DateTime.utc(2027, 1, 1),
      ),
    ], now);

    expect(expiry, DateTime.utc(2026, 11, 3, 12));
    expect(formatPlusExpiryDate(expiry!), '2026/11/03');
  });

  test('does not invent an expiry when the store period has ended', () {
    expect(
      latestActivePlusExpiry([
        SubscriptionEntitlementRecord(
          productId: SubscriptionCatalog.monthlyProductId,
          expiresAt: DateTime.utc(2026, 10, 1),
        ),
      ], now),
      isNull,
    );
  });
}
