import 'package:flutter/foundation.dart';

import 'in_app_browser_detector_stub.dart'
    if (dart.library.html) 'in_app_browser_detector_web.dart'
    as probe;

/// LINE 等のアプリ内ブラウザ判定。
abstract final class InAppBrowserDetector {
  static bool get shouldRecommendExternalBrowser {
    if (!kIsWeb) {
      return false;
    }
    return probe.detectInAppBrowserUserAgent();
  }
}
