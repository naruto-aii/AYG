/// ブランド Asset パス。すべて Figma から書き出したベクター。
abstract final class BrandAssets {
  /// ブランドマーク（円＋葉＋オレンジの点）。Figma の BrandMark/Tight。
  static const String brandMarkSvg = 'assets/brand/app_brand_mark.svg';

  /// スプラッシュ用のマーク。オレンジの点を含まない（点は別途アニメーションする）。
  static const String splashMarkSvg = 'assets/brand/splash_mark.svg';

  /// ログイン画面の背景（波・アーク・葉）を1枚にまとめたもの。390×844。
  static const String loginBackgroundSvg = 'assets/brand/login_background.svg';

  /// 背景の下の丘（波3本）。画面の下端に貼り付ける。
  static const String backgroundHillsSvg = 'assets/brand/bg_hills.svg';

  /// 背景の左上のアーク。画面の左上に貼り付ける。
  static const String backgroundArcSvg = 'assets/brand/bg_arc.svg';

  /// 背景の右の葉。画面の右端に貼り付ける。
  static const String backgroundPlantSvg = 'assets/brand/bg_plant.svg';

  /// Google ブランドマーク（4色の G）。20×20。
  static const String googleMarkSvg = 'assets/brand/google_mark.svg';

  /// Apple ブランドマーク。28×28。
  static const String appleMarkSvg = 'assets/brand/apple_mark.svg';

  /// 暫定アプリアイコン（装飾のみ・日本語なし）。
  static const String iconPlaceholderSvg =
      'assets/brand/app_icon_placeholder.svg';
}
