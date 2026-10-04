import '../config/subscription_catalog.dart';
import 'subscription_entitlement.dart';

enum PlusBillingPeriod { month, semiannual, year, other }

class SubscriptionProductOffer {
  const SubscriptionProductOffer({
    required this.productId,
    required this.period,
    required this.localizedPrice,
  });

  final String productId;
  final PlusBillingPeriod period;

  /// StoreKit localized price, for example `¥380` or `$2.99`.
  final String localizedPrice;

  bool get canPurchase => localizedPrice.trim().isNotEmpty;

  String get buttonLabel => '${plusPeriodLabel(period)} $localizedPrice';
}

class SubscriptionOfferings {
  const SubscriptionOfferings({
    required this.monthly,
    required this.semiannual,
    required this.yearly,
    required this.loadFailed,
  });

  static const failed = SubscriptionOfferings(
    monthly: null,
    semiannual: null,
    yearly: null,
    loadFailed: true,
  );

  final SubscriptionProductOffer? monthly;
  final SubscriptionProductOffer? semiannual;
  final SubscriptionProductOffer? yearly;
  final bool loadFailed;
}

String plusPeriodLabel(PlusBillingPeriod period) {
  return switch (period) {
    PlusBillingPeriod.month => '月額',
    PlusBillingPeriod.semiannual => '半年',
    PlusBillingPeriod.year => '年額',
    PlusBillingPeriod.other => '定期購入',
  };
}

/// まだ期限が来ていない加入のうち、いちばん遅い期限。無いときは null。
DateTime? latestActivePlusExpiry(
  List<SubscriptionEntitlementRecord> records,
  DateTime now,
) {
  DateTime? best;
  for (final record in records) {
    if (!SubscriptionCatalog.isPlusProduct(record.productId)) {
      continue;
    }
    final expiry = record.expiresAt;
    if (expiry == null || !expiry.isAfter(now)) {
      continue;
    }
    if (best == null || expiry.isAfter(best)) {
      best = expiry;
    }
  }
  return best;
}

/// 画面に出す期限。ストアが返した日時だけを使い、無い期限は作らない。
String formatPlusExpiryDate(DateTime expiry) {
  final local = expiry.toLocal();
  final year = local.year.toString().padLeft(4, '0');
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$year/$month/$day';
}

PlusBillingPeriod periodForProduct({
  required String productId,
  PlusBillingPeriod? storePeriod,
}) {
  if (storePeriod != null && storePeriod != PlusBillingPeriod.other) {
    return storePeriod;
  }
  if (productId == SubscriptionCatalog.monthlyProductId) {
    return PlusBillingPeriod.month;
  }
  if (productId == SubscriptionCatalog.semiannualProductId) {
    return PlusBillingPeriod.semiannual;
  }
  if (productId == SubscriptionCatalog.yearlyProductId) {
    return PlusBillingPeriod.year;
  }
  return PlusBillingPeriod.other;
}
