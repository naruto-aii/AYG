/// 食品成分表の検索・記録。
///
/// define が無いときはオン。iOS の Debug / Profile / Release（Xcode Archive を含む）は
/// `officialFoodsEnabled=true` を渡す。テストは [debugOverride] で切り替える。
abstract final class OfficialFoodsFlag {
  static bool? debugOverride;

  static bool get enabled {
    final override = debugOverride;
    if (override != null) {
      return override;
    }
    return const bool.fromEnvironment(
      'officialFoodsEnabled',
      defaultValue: true,
    );
  }
}
