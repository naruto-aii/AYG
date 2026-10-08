import 'dart:io';

import 'package:ayg/services/analytics/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 利用状況の記録は専用の同意画面を出さず、規約とプライバシーポリシーへの同意
/// （ログイン）に含める。止める設定は「規約とポリシー」の中に控えめに残す。
void main() {
  const sentence = 'アプリの利用状況などのデータは、サービス改善のための分析に使う場合があります';

  test('the dedicated consent screen is gone from the first launch', () {
    expect(
      File('lib/screens/consent/analytics_consent_screen.dart').existsSync(),
      isFalse,
    );
    final app = File('lib/app.dart').readAsStringSync();
    expect(app, isNot(contains('AnalyticsConsentScreen')));
    expect(app, contains('analyticsAgreementSurface'));
    expect(
      RegExp(r'^[a-z][a-z0-9_]{1,30}$').hasMatch(analyticsAgreementSurface),
      isTrue,
      reason: 'analytics_consents.surface check constraint',
    );
  });

  test('privacy policy and terms carry the analytics sentence', () {
    for (final path in [
      'legal/privacy.html',
      'docs/legal/privacy.html',
      'legal/terms.html',
      'docs/legal/terms.html',
    ]) {
      final html = File(path).readAsStringSync();
      expect(html, contains(sentence), reason: path);
      expect(html, isNot(contains('協力した人についてだけ')), reason: path);
      expect(html, isNot(contains('ログインの前に協力するかどうか')), reason: path);
    }
    expect(
      File('legal/privacy.html').readAsStringSync(),
      File('docs/legal/privacy.html').readAsStringSync(),
    );
  });

  test('the opt-out lives quietly under 規約とポリシー', () {
    final settings = File(
      'lib/screens/settings/settings_screen.dart',
    ).readAsStringSync();
    expect(settings, isNot(contains('settings-analytics')));
    final policies = File(
      'lib/screens/settings/settings_policies_screen.dart',
    ).readAsStringSync();
    expect(policies, contains('settings-analytics'));
    expect(policies, contains('AnalyticsSettingsScreen'));
  });

  test('no advertising tracking is declared', () {
    final manifest = File('ios/Runner/PrivacyInfo.xcprivacy').readAsStringSync();
    expect(
      RegExp(r'<key>NSPrivacyTracking</key>\s*<false/>').hasMatch(manifest),
      isTrue,
    );
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, isNot(contains('NSUserTrackingUsageDescription')));
  });
}
