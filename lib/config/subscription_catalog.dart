/// 選んでから買うプラン。金額は持たない。
enum PlusPlan { monthly, halfYear, yearly }

/// カロナビ+ の商品と無料枠。App Store Connect の Product ID と揃える。
///
/// 金額はここに書かない。表示も購入も、ストアが返す商品だけを使う。
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const productName = 'カロナビ+';
  static const monthlyProductId = 'calonavi_plus_monthly';
  static const halfYearProductId = 'calonavi_plus_half_year';
  static const yearlyProductId = 'calonavi_plus_yearly';

  /// 実機テストの切替だけが書く商品ID。StoreKit の商品照会には入れない。
  static const testPurchaseProductId = 'calonavi_plus_test';

  static const plusProductIds = <String>{
    monthlyProductId,
    halfYearProductId,
    yearlyProductId,
  };

  static const publicFoodSearchesPerDay = 5;

  /// 無料で作れる食事テンプレートの件数。カロナビ+は件数の上限なし。
  static const mealTemplateLimit = 4;
  static const workoutTemplateLimit = 4;

  /// 保存済みが上限以上で、カロナビ+でなければ、新しい食事テンプレートは有料。
  static bool mealTemplateCreateRequiresPlus({
    required int savedCount,
    required bool isPlus,
  }) {
    return !isPlus && savedCount >= mealTemplateLimit;
  }

  static bool isPlusProduct(String productId) {
    return plusProductIds.contains(productId);
  }

  /// 端末から Supabase へ写す加入。テスト用IDはストア商品ではない。
  static bool syncsEntitlement(String productId) {
    return isPlusProduct(productId) || productId == testPurchaseProductId;
  }

  static String productIdFor(PlusPlan plan) {
    return switch (plan) {
      PlusPlan.monthly => monthlyProductId,
      PlusPlan.halfYear => halfYearProductId,
      PlusPlan.yearly => yearlyProductId,
    };
  }
}
