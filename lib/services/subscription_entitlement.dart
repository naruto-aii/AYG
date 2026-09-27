import '../config/subscription_catalog.dart';

class SubscriptionEntitlementRecord {
  const SubscriptionEntitlementRecord({
    required this.productId,
    required this.expiresAt,
  });

  final String productId;

  /// Null when the store did not provide an expiry. That is not an active grant.
  final DateTime? expiresAt;
}

/// Plus access follows the latest unexpired subscription, not a sticky flag.
class SubscriptionEntitlementState {
  SubscriptionEntitlementState([Map<String, DateTime>? initial])
    : expiryByProduct = Map<String, DateTime>.of(initial ?? const {});

  final Map<String, DateTime> expiryByProduct;

  void apply(SubscriptionEntitlementRecord record) {
    if (!SubscriptionCatalog.isPlusProduct(record.productId)) {
      return;
    }
    final expiry = record.expiresAt;
    if (expiry == null) {
      expiryByProduct.remove(record.productId);
      return;
    }
    expiryByProduct[record.productId] = expiry;
  }

  void replaceAll(Iterable<SubscriptionEntitlementRecord> records) {
    expiryByProduct.clear();
    for (final record in records) {
      apply(record);
    }
  }

  DateTime? get latestExpiry {
    DateTime? best;
    for (final expiry in expiryByProduct.values) {
      if (best == null || expiry.isAfter(best)) {
        best = expiry;
      }
    }
    return best;
  }

  bool isActive(DateTime now) {
    final expiry = latestExpiry;
    return expiry != null && expiry.isAfter(now);
  }
}

DateTime? parseStoreExpiryMillis(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final millis = int.tryParse(raw);
  if (millis == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(millis);
}
