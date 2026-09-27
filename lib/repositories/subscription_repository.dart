import '../services/subscription_offer.dart';

/// カロナビ+ の加入状態と購入。
abstract class SubscriptionRepository {
  bool get isPlusActive;

  Stream<bool> get plusChanges;

  /// Store prices. Callers must not invent a price when this fails.
  Future<SubscriptionOfferings> loadOfferings();

  Future<void> restore();

  Future<void> purchaseMonthly();

  Future<void> purchaseYearly();
}
