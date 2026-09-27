import '../services/subscription_offer.dart';

/// カロナビ+ の加入状態と購入。
abstract class SubscriptionRepository {
  bool get isPlusActive;

  Stream<bool> get plusChanges;

  /// Store prices. Callers must not invent a price when this fails.
  Future<SubscriptionOfferings> loadOfferings();

  Future<void> restore();

  /// Re-read the store, then recompute Plus from the clock.
  /// A no-op where there is no store.
  Future<void> refreshEntitlement();

  Future<void> purchaseMonthly();

  Future<void> purchaseYearly();
}
