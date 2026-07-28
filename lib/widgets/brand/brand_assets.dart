/// ブランド Asset パス（SVG / 画像差し替え用）。
abstract final class BrandAssets {
  /// 将来: 文字込み正式ロゴSVG。現在は AppLogo が Text + brandMark を使用。
  static const String fullLogoSvg = 'assets/brand/app_logo.svg';

  /// 暫定ブランドマーク（装飾のみ・日本語なし）。
  static const String brandMarkSvg = 'assets/brand/app_brand_mark.svg';

  /// 暫定アプリアイコン（装飾のみ・日本語なし）。
  static const String iconPlaceholderSvg =
      'assets/brand/app_icon_placeholder.svg';
}
