import '../config/subscription_catalog.dart';
import 'subscription_entitlement.dart';

enum PlusBillingPeriod { month, halfYear, year, other }

class SubscriptionProductOffer {
  const SubscriptionProductOffer({
    required this.productId,
    required this.period,
    required this.localizedPrice,
    this.freeTrialDays,
  });

  final String productId;

  /// App Store Connect の「お試しオファー（無料）」の日数。
  /// ストアが無料のお試しを返し、この Apple ID が使えるときだけ入る。無いときは null。
  /// アプリ側で期間を数えることはしない。購入すれば StoreKit がそのまま適用する。
  final int? freeTrialDays;

  bool get hasFreeTrial => (freeTrialDays ?? 0) > 0;
  final PlusBillingPeriod period;

  /// StoreKit localized price, for example `¥380` or `$2.99`.
  final String localizedPrice;

  bool get canPurchase => localizedPrice.trim().isNotEmpty;

  String get buttonLabel => '${plusPeriodLabel(period)} $localizedPrice';
}

class SubscriptionOfferings {
  const SubscriptionOfferings({
    required this.monthly,
    this.halfYear,
    required this.yearly,
    required this.loadFailed,
  });

  static const failed = SubscriptionOfferings(
    monthly: null,
    halfYear: null,
    yearly: null,
    loadFailed: true,
  );

  final SubscriptionProductOffer? monthly;
  final SubscriptionProductOffer? halfYear;
  final SubscriptionProductOffer? yearly;
  final bool loadFailed;

  SubscriptionProductOffer? offerFor(PlusPlan plan) {
    return switch (plan) {
      PlusPlan.monthly => monthly,
      PlusPlan.halfYear => halfYear,
      PlusPlan.yearly => yearly,
    };
  }
}

String plusPeriodLabel(PlusBillingPeriod period) {
  return switch (period) {
    PlusBillingPeriod.month => '月額',
    PlusBillingPeriod.halfYear => '半年',
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
  if (productId == SubscriptionCatalog.halfYearProductId) {
    return PlusBillingPeriod.halfYear;
  }
  if (productId == SubscriptionCatalog.yearlyProductId) {
    return PlusBillingPeriod.year;
  }
  return PlusBillingPeriod.other;
}

String plusPlanLabel(PlusPlan plan) {
  return switch (plan) {
    PlusPlan.monthly => '月額',
    PlusPlan.halfYear => '半年',
    PlusPlan.yearly => '年額',
  };
}
