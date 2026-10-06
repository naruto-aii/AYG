/// 実機テスト用の有料／無料切替。
///
/// `./tool/run_ios.sh`（`--release` を付けた実機への入れ方を含む）だけが
/// `--dart-define=CALONAVI_TEST_PURCHASE=true` を渡す。
/// Xcode の Archive（App Store 提出用の Release）は
/// `ios/Flutter/Release.xcconfig` と `enable_official_foods_define.sh` だけを使い、
/// この define は付けない。未指定の既定は false。
const bool testPurchaseEnabled = bool.fromEnvironment(
  'CALONAVI_TEST_PURCHASE',
  defaultValue: false,
);
