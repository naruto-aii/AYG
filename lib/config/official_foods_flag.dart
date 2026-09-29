/// 食品成分表の検索・記録。
///
/// 本番は `--dart-define=officialFoodsEnabled=true` を付けるまでオフ。
/// テストは [debugOverride] で切り替える。
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
