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

  /// 公開から1ヶ月の初回だけ。月額には使わない。
  static const halfYearIntroProductId = 'calonavi_plus_half_year_intro';
  static const yearlyIntroProductId = 'calonavi_plus_yearly_intro';

  /// 公開日時（UTC）。この瞬間から1ヶ月の間、半年と年額は初回の商品IDを買う。
  static final DateTime introWindowStart = DateTime.utc(2026, 10, 4);

  static const plusProductIds = <String>{
    monthlyProductId,
    halfYearProductId,
    yearlyProductId,
    halfYearIntroProductId,
    yearlyIntroProductId,
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

  /// 公開日時から1ヶ月、半年と年額だけ初回の商品にする。月額はいつも同じ。
  static bool introWindowOpen(DateTime now) {
    final start = introWindowStart.toUtc();
    final end = DateTime.utc(
      start.year,
      start.month + 1,
      start.day,
      start.hour,
      start.minute,
      start.second,
      start.millisecond,
      start.microsecond,
    );
    final instant = now.toUtc();
    return !instant.isBefore(start) && instant.isBefore(end);
  }

  static String productIdFor(PlusPlan plan, DateTime now) {
    final intro = introWindowOpen(now);
    return switch (plan) {
      PlusPlan.monthly => monthlyProductId,
      PlusPlan.halfYear => intro ? halfYearIntroProductId : halfYearProductId,
      PlusPlan.yearly => intro ? yearlyIntroProductId : yearlyProductId,
    };
  }
}
