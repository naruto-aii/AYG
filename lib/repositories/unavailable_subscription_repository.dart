import '../config/subscription_catalog.dart';
import '../services/subscription_offer.dart';
import 'subscription_exceptions.dart';
import 'subscription_repository.dart';

/// Web Preview など、ストア課金が無い環境。
class UnavailableSubscriptionRepository extends SubscriptionRepository {
  @override
  bool get isPlusActive => false;

  @override
  Stream<bool> get plusChanges => const Stream.empty();

  @override
  Future<SubscriptionOfferings> loadOfferings() async {
    return SubscriptionOfferings.failed;
  }

  @override
  Future<void> restore() async {}

  @override
  Future<void> refreshEntitlement() async {}

  @override
  Future<void> purchaseMonthly() {
    throw SubscriptionPurchaseUnavailableException();
  }

  @override
  Future<void> purchaseYearly() {
    throw SubscriptionPurchaseUnavailableException();
  }

  @override
  Future<void> purchasePlan(PlusPlan plan) {
    throw SubscriptionPurchaseUnavailableException();
  }
}
