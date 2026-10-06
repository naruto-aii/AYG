import 'package:flutter/foundation.dart';

import 'test_purchase.dart';

/// テスト購入フラグが無い debug / profile の flutter run だけ true。
///
/// フラグがあるビルドは常時有料にしない。購入ボタンと設定の「無料に戻す」で切り替える。
/// release と審査用 Archive は false。
///
/// 外すときはこのファイルと、bootstrap から渡している引数を消す。
const bool developmentPlusPreview = !testPurchaseEnabled && !kReleaseMode;
