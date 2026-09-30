/// 食事目標の出し方。手入力中は自動計算で上書きしない。
enum CalorieTargetMode {
  automatic,
  manual;

  static CalorieTargetMode fromName(String? raw) {
    if (raw == manual.name) {
      return CalorieTargetMode.manual;
    }
    return CalorieTargetMode.automatic;
  }

  String get labelJa => switch (this) {
    CalorieTargetMode.automatic => '自動で計算',
    CalorieTargetMode.manual => '自分で入力',
  };
}
