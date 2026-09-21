/// カロナビ+ の商品と無料枠。App Store Connect の Product ID と揃える。
class SubscriptionCatalog {
  SubscriptionCatalog._();

  static const productName = 'カロナビ+';
  static const monthlyProductId = 'calonavi_plus_monthly';
  static const yearlyProductId = 'calonavi_plus_yearly';

  static const monthlyYen = 380;
  static const yearlyYen = 4180;

  static const publicFoodSearchesPerDay = 5;
  static const mealTemplateLimit = 3;
  static const workoutTemplateLimit = 3;

  static const monthlyLabel = '月額 380円';
  static const yearlyLabel = '年額 4,180円';
  static const yearlySavingLabel = '1ヶ月分お得';
}
