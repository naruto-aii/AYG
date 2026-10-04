import 'package:flutter/foundation.dart';

/// debug と profile の flutter run だけ true。release と審査用ビルドは false。
///
/// 外すときはこのファイルと、bootstrap から渡している引数を消す。
const bool developmentPlusPreview = !kReleaseMode;
