/// ブランド Asset パス。すべて Figma から書き出したベクター。
abstract final class BrandAssets {
  /// ブランドマーク（円＋葉＋オレンジの点）。96×96 の viewBox。
  static const String brandMarkSvg = 'assets/brand/app_brand_mark.svg';

  /// ログイン画面の背景（波・アーク・葉）。390×844 の viewBox。
  static const String loginBackgroundSvg = 'assets/brand/login_background.svg';

  /// Google ブランドマーク（4色の G）。20×20。
  static const String googleMarkSvg = 'assets/brand/google_mark.svg';

  /// Apple ブランドマーク。28×28。
  static const String appleMarkSvg = 'assets/brand/apple_mark.svg';

  /// 暫定アプリアイコン（装飾のみ・日本語なし）。
  static const String iconPlaceholderSvg =
      'assets/brand/app_icon_placeholder.svg';
}
