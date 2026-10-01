/// Health 連携時に、画面の消費へ足す活動量。
///
/// 朝の基礎は、その日の食事目標と同じ推定安静時消費（REE）。
/// 生活活動係数で見込む活動は REE ×（係数 − 1）。これは食事目標の
/// REE × 係数に既に入っている。Health のアクティブエネルギー
/// （安静を含まない当日分）からその分を引き、正の残りだけを足す。
///
/// 戻し方: このクラスの [kcal] を常に 0 にする。食事目標は変更前から
/// REE × 生活活動係数のままで、Health のアクティブエネルギーは
/// 残りカロリーに足していなかった（画面では参考表示のみ）。
/// 識別子は [version]。
class HealthActivityExcess {
  const HealthActivityExcess();

  static const version = 'health_activity_excess_v1';

  /// 連携していない、基礎か係数か当日のアクティブエネルギーが無い、
  /// または生活活動分を超えないときは 0。不足分は引かない。
  double kcal({
    required bool useHealthIntegration,
    required double? basalReeKcal,
    required double? lifestyleFactor,
    required double? activeEnergyBurnedKcal,
  }) {
    if (!useHealthIntegration) {
      return 0;
    }
    final aboveBasal = lifestyleAboveBasalKcal(
      basalReeKcal: basalReeKcal,
      lifestyleFactor: lifestyleFactor,
    );
    if (aboveBasal == null ||
        activeEnergyBurnedKcal == null ||
        !activeEnergyBurnedKcal.isFinite ||
        activeEnergyBurnedKcal < 0) {
      return 0;
    }
    final excess = activeEnergyBurnedKcal - aboveBasal;
    if (!excess.isFinite || excess <= 0) {
      return 0;
    }
    return excess;
  }

  /// REE ×（生活活動係数 − 1）。食事目標に入っている活動分。
  double? lifestyleAboveBasalKcal({
    required double? basalReeKcal,
    required double? lifestyleFactor,
  }) {
    if (basalReeKcal == null ||
        lifestyleFactor == null ||
        !basalReeKcal.isFinite ||
        !lifestyleFactor.isFinite ||
        basalReeKcal <= 0 ||
        lifestyleFactor < 1) {
      return null;
    }
    final above = basalReeKcal * (lifestyleFactor - 1);
    if (!above.isFinite || above < 0) {
      return null;
    }
    return above;
  }
}
