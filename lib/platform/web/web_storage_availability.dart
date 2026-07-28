import 'package:flutter/foundation.dart';

import 'web_storage_probe.dart';

/// Web Storage の利用可否を安全に確認する。
abstract final class WebStorageAvailability {
  static bool get isLocalStorageAvailable {
    if (!kIsWeb) {
      return true;
    }
    return probeWebLocalStorage();
  }
}
