import 'package:flutter/foundation.dart';

/// debug / profile の flutter run だけ true。
///
/// release と審査用 Archive は false。購入しないとカロナビ+にならない。
const bool developmentPlusPreview = !kReleaseMode;
