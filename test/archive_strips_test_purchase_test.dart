import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `./tool/run_ios.sh` の後に Xcode で Archive しても、実機テスト用の
/// 有料切替が提出用ビルドに入らないことを、ビルドフェーズの台本で確かめる。
void main() {
  String define(String text) => base64.encode(utf8.encode(text));

  List<String> run(String action, List<String> defines) {
    final result = Process.runSync('/bin/sh', [
      '-c',
      '. ios/Flutter/enable_official_foods_define.sh; printf %s "\$DART_DEFINES"',
    ], environment: {'ACTION': action, 'DART_DEFINES': defines.join(',')});
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return [
      for (final part in (result.stdout as String).split(','))
        utf8.decode(base64.decode(part)),
    ];
  }

  final fromRunIos = [
    define('SUPABASE_URL=https://example.supabase.co'),
    define('CALONAVI_TEST_PURCHASE=true'),
    define('officialFoodsEnabled=true'),
  ];

  test('Archive drops the device-test purchase switch and keeps the rest', () {
    expect(run('install', fromRunIos), [
      'SUPABASE_URL=https://example.supabase.co',
      'officialFoodsEnabled=true',
    ]);
    expect(
      run('install', [define('CALONAVI_TEST_PURCHASE=false')]),
      ['officialFoodsEnabled=true'],
    );
  });

  test('flutter run --release (xcodebuild build) keeps it', () {
    expect(run('build', fromRunIos), [
      'SUPABASE_URL=https://example.supabase.co',
      'CALONAVI_TEST_PURCHASE=true',
      'officialFoodsEnabled=true',
    ]);
  });
}
