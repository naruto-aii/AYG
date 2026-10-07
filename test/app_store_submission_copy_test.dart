import 'dart:io';

import 'package:ayg/content/daily_calorie_target_explanation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS copy does not name another store or OS', () {
    final explanation = DailyCalorieTargetExplanation.sections
        .map((section) => '${section.$1}\n${section.$2}')
        .join('\n');
    expect(explanation, isNot(contains('Android')));
    expect(explanation, isNot(contains('Google Play')));
    expect(explanation, isNot(contains('Health Connect')));
    expect(explanation, contains('ヘルスケア'));

    for (final path in [
      'legal/terms.html',
      'legal/tokushoho.html',
      'docs/legal/terms.html',
      'docs/legal/tokushoho.html',
    ]) {
      final html = File(path).readAsStringSync();
      expect(html, isNot(contains('Google Play')), reason: path);
      expect(html, isNot(contains('Android')), reason: path);
      expect(html, contains('App Store'), reason: path);
    }
  });

  test('Sign in with Apple and Health purpose strings are in the iOS target', () {
    final entitlements = File(
      'ios/Runner/Runner.entitlements',
    ).readAsStringSync();
    expect(entitlements, contains('com.apple.developer.applesignin'));
    expect(entitlements, contains('Default'));

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('NSHealthShareUsageDescription'));
    expect(plist, contains('生年月日、性別、身長、体重、アクティブエネルギー、ワークアウト'));
    expect(plist, contains('ヘルスケアへ書き込みません'));
    expect(plist, isNot(contains('必要に応じてHealthデータを更新')));
  });
}
