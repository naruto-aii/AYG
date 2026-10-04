/// カロナビ+ の商品と無料枠。App Store Connect の Product ID と揃える。
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const productName = 'カロナビ+';
  static const monthlyProductId = 'calonavi_plus_monthly';
  static const yearlyProductId = 'calonavi_plus_yearly';

  static const publicFoodSearchesPerDay = 5;

  /// 無料で作れる食事テンプレートの件数。5件目からカロナビ+。
  static const mealTemplateLimit = 4;
  static const workoutTemplateLimit = 3;

  /// 保存済みが上限以上で、カロナビ+でなければ、新しい食事テンプレートは有料。
  static bool mealTemplateCreateRequiresPlus({
    required int savedCount,
    required bool isPlus,
  }) {
    return !isPlus && savedCount >= mealTemplateLimit;
  }

  static bool isPlusProduct(String productId) {
    return productId == monthlyProductId || productId == yearlyProductId;
  }
}
