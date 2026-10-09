import '../config/subscription_catalog.dart';
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

  /// StoreKit が自分で `entitlement_observed` を送るとき true。
  bool get reportsEntitlementAnalytics => false;

  /// 購入の appAccountToken に使う、小文字の利用者番号。
  void bindStoreAccountToken(String? userId) {}

  String? get storeOriginalTransactionId => null;

  Future<void> purchaseMonthly();

  Future<void> purchaseYearly();

  /// 選んだプランの商品IDでストアの購入を開く。未選択では呼ばない。
  Future<void> purchasePlan(PlusPlan plan);

  /// `--dart-define=CALONAVI_TEST_PURCHASE=true` のビルドだけ true。
  bool get testPurchaseToggleEnabled => false;

  /// テスト用の有料を消す。フラグが無いビルドでは何もしない。
  Future<void> clearTestPurchase() async {}

  /// 実機テスト用ビルドだけ。アプリを入れ直して切替がまだ一度も押されていないとき、
  /// サーバで有料なら有料として表示する。押した後は押した状態を優先する。
  void adoptServerPlusForTest(bool serverPlus) {}
}
