import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_lifecycle.dart';
import 'analytics_route_observer.dart';
import 'apple_ads_attribution.dart';

/// 起動時に一度だけ置く。未設定のテストでは空のまま。
abstract final class AnalyticsRuntime {
  static AnalyticsLifecycle? lifecycle;
  static AppleAdsAttribution? ads;
  static AnalyticsRouteObserver? routes;
  static SharedPreferences? preferences;
}
