import 'subscription_exceptions.dart';
import 'subscription_repository.dart';

/// Web Preview など、ストア課金が無い環境。
class UnavailableSubscriptionRepository extends SubscriptionRepository {
  @override
  bool get isPlusActive => false;

  @override
  Stream<bool> get plusChanges => const Stream.empty();

  @override
  Future<void> restore() async {}

  @override
  Future<void> purchaseMonthly() {
    throw SubscriptionPurchaseUnavailableException();
  }

  @override
  Future<void> purchaseYearly() {
    throw SubscriptionPurchaseUnavailableException();
  }
}
