import '../data/met_activity_catalog.dart';

/// 20:00（日本時間）の通知文。
///
/// 数字は送る瞬間の食事・運動・目標から埋める。以前に組み立てた文は使わない。
class DailyCalorieReminderCopy {
  const DailyCalorieReminderCopy._();

  static const noRecords = '今日の食事、運動が登録されてません！今のうちに登録しましょう！';

  /// プロフィールに正の体重が無いときだけ使う。ランニングの式自体はカタログのまま。
  static const fallbackWeightKg = 60.0;

  static String remaining(int kcal) => '今日あと${kcal}kcal食べられます！';

  static String overage(int kcal, String kilometers) =>
      '今日は${kcal}kcalオーバーしてます！${kilometers}kmランニングすればチャラにできますよ！';

  /// ホームのカロリーリングと同じ、小数0桁への丸め。
  static int roundKcal(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return int.parse(value.toStringAsFixed(0));
  }

  /// ランニングの既存モデル（kcal = 係数 × 体重kg × 距離km）で、超過分を距離にする。
  ///
  /// 係数は [MetActivityCatalog] の `running`。1桁に丸め、超過が正なら 0.1 未満にはしない。
  static String runningKilometers({
    required double excessKcal,
    required double weightKg,
  }) {
    if (!(excessKcal > 0)) {
      return '0.0';
    }
    final factor =
        MetActivityCatalog.findById('running')?.netKcalPerKgKm ?? 1.0;
    final weight = weightKg.isFinite && weightKg > 0
        ? weightKg
        : fallbackWeightKg;
    final raw = excessKcal / (factor * weight);
    final rounded = _roundOneDecimal(raw);
    final shown = rounded < 0.1 ? 0.1 : rounded;
    return shown.toStringAsFixed(1);
  }

  static double _roundOneDecimal(double value) {
    if (!value.isFinite) {
      return 0;
    }
    return (value * 10).roundToDouble() / 10;
  }

  /// [mealCount] は食事の記録件数、[exerciseCount] は運動の記録件数。
  ///
  /// 残りはホームと同じく、目標 + 運動の net + Health の上乗せ − 摂取。
  /// 摂取には食事とアルコールを含める。アルコールだけの日は、食事も運動も
  /// 無ければ登録を促す文になる。
  static String build({
    required int mealCount,
    required int exerciseCount,
    required double goalFoodTargetKcal,
    required double intakeKcal,
    required double exerciseNetKcal,
    required double healthExcessKcal,
    required double weightKg,
  }) {
    if (mealCount <= 0 && exerciseCount <= 0) {
      return noRecords;
    }
    final remaining =
        goalFoodTargetKcal + exerciseNetKcal + healthExcessKcal - intakeKcal;
    if (!remaining.isFinite) {
      return noRecords;
    }
    if (remaining >= 0) {
      return DailyCalorieReminderCopy.remaining(roundKcal(remaining));
    }
    final excess = remaining.abs();
    return overage(
      roundKcal(excess),
      runningKilometers(
        excessKcal: roundKcal(excess).toDouble(),
        weightKg: weightKg,
      ),
    );
  }
}

/// システムの許可状態から、ダイアログを出すかトークンを送るか。
bool dailyReminderShouldRequest({
  required String status,
  required bool requestIfNeeded,
}) {
  return requestIfNeeded && status == 'notDetermined';
}

bool dailyReminderShouldUploadToken(String status) {
  return status == 'authorized' ||
      status == 'provisional' ||
      status == 'ephemeral';
}
