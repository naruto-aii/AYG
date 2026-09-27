/// カロナビ+ の加入状態と購入。
abstract class SubscriptionRepository {
  bool get isPlusActive;

  Stream<bool> get plusChanges;

  Future<void> restore();

  Future<void> purchaseMonthly();

  Future<void> purchaseYearly();
}
