import 'package:flutter/foundation.dart';

/// Web プレビュー専用の OAuth リダイレクト。
///
/// モバイルの Google ログインはネイティブ SDK で完結する。
/// この URL が無くてもアプリは動く。Web プレビューを非公開にすると、
/// 壊れるのは Web 上の Google ログインだけである。
abstract final class WebAuthConfig {
  static const String productionRedirectUrl =
      'https://naruto-aii.github.io/AYG/';

  /// OAuth完了後のリダイレクト先（GitHub Pages /AYG/ 配下）。
  static String get redirectUrl {
    if (!kIsWeb) {
      return productionRedirectUrl;
    }

    final base = Uri.base;
    if (base.origin.isEmpty || base.origin == 'null') {
      return productionRedirectUrl;
    }

    var path = base.path;
    if (!path.endsWith('/')) {
      path = '$path/';
    }
    return '${base.origin}$path';
  }
}
