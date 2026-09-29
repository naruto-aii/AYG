import 'package:web/web.dart' as web;

bool detectInAppBrowserUserAgent() {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  return userAgent.contains('line') ||
      userAgent.contains('fbav') ||
      userAgent.contains('instagram') ||
      userAgent.contains('twitter') ||
      userAgent.contains('micromessenger');
}
