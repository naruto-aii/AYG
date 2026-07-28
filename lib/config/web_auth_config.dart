import 'package:flutter/foundation.dart';

/// Web OAuth / リダイレクト設定。
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
