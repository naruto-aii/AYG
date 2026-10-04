/// カロナビ+ の商品と無料枠。App Store Connect の Product ID と揃える。
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const productName = 'カロナビ+';
  static const monthlyProductId = 'calonavi_plus_monthly';
  static const semiannualProductId = 'calonavi_plus_semiannual';
  static const yearlyProductId = 'calonavi_plus_yearly';

  static const mealTemplateLimit = 4;
  static const workoutTemplateLimit = 4;

  static bool isPlusProduct(String productId) {
    return productId == monthlyProductId ||
        productId == semiannualProductId ||
        productId == yearlyProductId;
  }
}
