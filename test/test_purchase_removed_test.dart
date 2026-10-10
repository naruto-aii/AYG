import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// PR #80 のワンタップ切替（CALONAVI_TEST_PURCHASE）が、コードと画面に残っていない。
void main() {
  const needles = [
    'CALONAVI_TEST_PURCHASE',
    'testPurchaseEnabled',
    'testPurchaseToggleEnabled',
    'clearTestPurchase',
    'test-purchase-revert',
    'テスト用: 無料に戻す',
    'テスト用にカロナビ+にしました',
    'calonavi_plus_test_override',
  ];

  const paths = [
    'tool/run_ios.sh',
    'tool/prepare_ios_release.sh',
    'ios/Flutter/enable_official_foods_define.sh',
    'ios/Flutter/Release.xcconfig',
    'lib/bootstrap/native_bootstrap.dart',
    'lib/config/development_plus_preview.dart',
    'lib/config/subscription_catalog.dart',
    'lib/repositories/subscription_repository.dart',
    'lib/repositories/storekit_subscription_repository.dart',
    'lib/screens/settings/settings_screen.dart',
    'lib/screens/subscription/calonavi_plus_flow.dart',
    'lib/state/app_controller.dart',
    'README.md',
  ];

  test('the one-tap Plus switch is gone from code and screens', () {
    expect(File('lib/config/test_purchase.dart').existsSync(), isFalse);
    for (final path in paths) {
      final text = File(path).readAsStringSync();
      for (final needle in needles) {
        expect(text, isNot(contains(needle)), reason: '$path still has $needle');
      }
    }
  });

  test('config-only always loads dart defines from the local file', () {
    final script = File('tool/prepare_ios_release.sh').readAsStringSync();
    expect(script, contains('flutter build ios --config-only'));
    expect(
      script,
      contains('--dart-define-from-file='),
    );
    expect(script, contains('tool/dart_defines.local.json'));
    final command = script
        .split('\n')
        .skipWhile((line) => !line.contains('flutter build ios --config-only'))
        .take(2)
        .join('\n');
    expect(command, contains('--dart-define-from-file='));
    expect(command, contains('tool/dart_defines.local.json'));
  });
}
