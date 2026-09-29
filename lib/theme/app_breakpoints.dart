/// レスポンシブレイアウトのブレークポイントと最大幅。
abstract final class AppBreakpoints {
  /// [ResponsiveSummaryGrid] と同じ2カラム切替幅。
  static const double summaryGrid = 480;

  /// Bottom Navigation から Sidebar Navigation へ切り替える幅。
  static const double desktop = 900;

  /// 本文コンテンツの最大幅。
  static const double contentMaxWidth = 960;

  /// 入力フォームの最大幅。
  static const double formMaxWidth = 640;

  /// 左 Sidebar の幅。
  static const double sidebarWidth = 240;
}
