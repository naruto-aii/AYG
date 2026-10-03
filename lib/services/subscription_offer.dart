import '../config/subscription_catalog.dart';

enum PlusBillingPeriod { month, year, other }

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
    required this.yearly,
    required this.loadFailed,
  });

  static const failed = SubscriptionOfferings(
    monthly: null,
    yearly: null,
    loadFailed: true,
  );

  final SubscriptionProductOffer? monthly;
  final SubscriptionProductOffer? yearly;
  final bool loadFailed;
}

String plusPeriodLabel(PlusBillingPeriod period) {
  return switch (period) {
    PlusBillingPeriod.month => '月額',
    PlusBillingPeriod.year => '年額',
    PlusBillingPeriod.other => '定期購入',
  };
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
  if (productId == SubscriptionCatalog.yearlyProductId) {
    return PlusBillingPeriod.year;
  }
  return PlusBillingPeriod.other;
}
