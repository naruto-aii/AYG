import 'package:ayg/config/subscription_catalog.dart';
import 'package:ayg/repositories/unavailable_subscription_repository.dart';
import 'package:ayg/services/subscription_offer.dart';

/// ストアが税込価格を返したときと同じ金額。取得失敗の画面とは分ける。
SubscriptionOfferings catalogSubscriptionOfferings() {
  return const SubscriptionOfferings(
    monthly: SubscriptionProductOffer(
      productId: SubscriptionCatalog.monthlyProductId,
      period: PlusBillingPeriod.month,
      localizedPrice: '¥980',
    ),
    halfYear: SubscriptionProductOffer(
      productId: SubscriptionCatalog.halfYearProductId,
      period: PlusBillingPeriod.halfYear,
      localizedPrice: '¥4,900',
    ),
    yearly: SubscriptionProductOffer(
      productId: SubscriptionCatalog.yearlyProductId,
      period: PlusBillingPeriod.year,
      localizedPrice: '¥8,800',
    ),
    loadFailed: false,
  );
}

class CatalogPlusRepository extends UnavailableSubscriptionRepository {
  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return catalogSubscriptionOfferings();
  }
}
