import 'package:flutter/foundation.dart';

/// `--dart-define=CALONAVI_DEMO=true` を付けたデバッグ実行だけ有効。
///
/// Release は `kDebugMode` が false なので、定義が残っていても動かない。
const demoModeRequested = bool.fromEnvironment(
  'CALONAVI_DEMO',
  defaultValue: false,
);

bool get calonaviDemoMode => demoModeRequested && kDebugMode;
