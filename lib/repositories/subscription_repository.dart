import '../services/subscription_entitlement.dart';
import '../services/subscription_offer.dart';

/// カロナビ+ の加入状態と購入。
abstract class SubscriptionRepository {
  bool get isPlusActive;

  Stream<bool> get plusChanges;

  /// ストアが商品IDを返した加入。期限だけの端末キャッシュは含めない。
  List<SubscriptionEntitlementRecord> get confirmedEntitlements => const [];

  /// このセッションで取り消すか、権威のある再読込から消えた商品。
  List<SubscriptionEntitlementRecord> get inactiveEntitlements => const [];

  /// 直近のストア再読込が成功したか。失敗のときは他の商品を消さない。
  bool get entitlementAuthoritative => false;

  Stream<void> get entitlementChanges => const Stream.empty();

  /// Store prices. Callers must not invent a price when this fails.
  Future<SubscriptionOfferings> loadOfferings();

  Future<void> restore();

  /// Re-read the store, then recompute Plus from the clock.
  /// A no-op where there is no store.
  Future<void> refreshEntitlement();

  Future<void> purchaseMonthly();

  Future<void> purchaseYearly();
}
