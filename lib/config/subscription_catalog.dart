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

  static const plusProductIds = <String>{
    monthlyProductId,
    halfYearProductId,
    yearlyProductId,
  };

  static const publicFoodSearchesPerDay = 5;

  /// 無料で作れるテンプレートの件数。食事と運動はそれぞれこの件数まで。カロナビ+は上限なし。
  static const mealTemplateLimit = 4;
  static const workoutTemplateLimit = 4;

  /// 保存済みが上限以上で、カロナビ+でなければ、新しい食事テンプレートは有料。
  static bool mealTemplateCreateRequiresPlus({
    required int savedCount,
    required bool isPlus,
  }) {
    return !isPlus && savedCount >= mealTemplateLimit;
  }

  /// 保存済みが上限以上で、カロナビ+でなければ、新しい運動テンプレートは有料。
  static bool workoutTemplateCreateRequiresPlus({
    required int savedCount,
    required bool isPlus,
  }) {
    return !isPlus && savedCount >= workoutTemplateLimit;
  }

  static bool isPlusProduct(String productId) {
    return plusProductIds.contains(productId);
  }

  static String productIdFor(PlusPlan plan) {
    return switch (plan) {
      PlusPlan.monthly => monthlyProductId,
      PlusPlan.halfYear => halfYearProductId,
      PlusPlan.yearly => yearlyProductId,
    };
  }

  /// KPI を月額・半年・年額で分けるときの product_id。
  static const planMonthly = 'monthly';
  static const planHalfYear = 'half-year';
  static const planYearly = 'yearly';

  static String planKeyFor(PlusPlan plan) {
    return switch (plan) {
      PlusPlan.monthly => planMonthly,
      PlusPlan.halfYear => planHalfYear,
      PlusPlan.yearly => planYearly,
    };
  }

  /// ストアの商品IDも、すでにプランキーなら、そのキーに揃える。
  static String? planKeyForProduct(String? productId) {
    switch (productId) {
      case planMonthly:
      case monthlyProductId:
        return planMonthly;
      case planHalfYear:
      case 'half_year':
      case halfYearProductId:
        return planHalfYear;
      case planYearly:
      case yearlyProductId:
        return planYearly;
      default:
        return null;
    }
  }
}
