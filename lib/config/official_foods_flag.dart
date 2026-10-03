/// 食品成分表の検索・記録。
///
/// iOS の Debug / Profile / Release（Xcode Archive を含む）は
/// `officialFoodsEnabled=true` を渡す。Web の公開ビルドも同じ define を渡す。
/// 未指定のときはオフ。テストは [debugOverride] で切り替える。
abstract final class OfficialFoodsFlag {
  static bool? debugOverride;

  static bool get enabled {
    final override = debugOverride;
    if (override != null) {
      return override;
    }
    return const bool.fromEnvironment('officialFoodsEnabled');
  }
}
