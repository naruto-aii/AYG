import 'dart:convert';
import 'dart:io';

import 'package:ayg/config/google_client_id.dart';
import 'package:flutter_test/flutter_test.dart';

/// build 9 は Google ログインを押すと落ちた。iOS の Google Sign-In SDK は
/// URL スキーム（逆順クライアント ID）が無い・ID が壊れていると例外で落ちる。
/// その形のビルドを作らない・ネイティブを呼ばないことを確かめる。
void main() {
  const ios = '363500000000-iosabc123.apps.googleusercontent.com';
  const web = '363500000000-webdef456.apps.googleusercontent.com';
  const otherProjectIos = '999900000000-iosabc123.apps.googleusercontent.com';

  group('GoogleClientId', () {
    test('accepts a real client ID shape', () {
      expect(GoogleClientId.isValid(ios), isTrue);
      expect(
        GoogleClientId.reversed(ios),
        'com.googleusercontent.apps.363500000000-iosabc123',
      );
    });

    test('rejects bundle IDs, reversed IDs, comma lists and placeholders', () {
      for (final bad in [
        'com.narutoaii.ayg.web,com.narutoaii.ayg',
        'com.narutoaii.ayg',
        'com.googleusercontent.apps.363500000000-iosabc123',
        'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com',
        '$ios,$web',
        ' $ios',
        '',
      ]) {
        expect(GoogleClientId.isValid(bad), isFalse, reason: bad);
      }
    });

    test('iosProblem blocks native sign-in for broken settings', () {
      expect(
        GoogleClientId.iosProblem(iosClientId: ios, webClientId: web),
        isNull,
      );
      expect(
        GoogleClientId.iosProblem(iosClientId: '', webClientId: web),
        isNotNull,
      );
      expect(
        GoogleClientId.iosProblem(
          iosClientId: 'com.narutoaii.ayg.web,com.narutoaii.ayg',
          webClientId: web,
        ),
        isNotNull,
      );
      expect(
        GoogleClientId.iosProblem(
          iosClientId: otherProjectIos,
          webClientId: web,
        ),
        contains('different Google Cloud projects'),
      );
    });
  });

  group('Xcode Release guard (check_google_signin.sh)', () {
    String define(String text) => base64.encode(utf8.encode(text));

    ProcessResult run(Map<String, String> env) => Process.runSync(
      '/bin/sh',
      ['-c', '. ios/Flutter/enable_official_foods_define.sh; echo done'],
      environment: {'ACTION': 'install', 'CONFIGURATION': 'Release', ...env},
    );

    final defines = [
      define('SUPABASE_URL=https://example.supabase.co'),
      define('GOOGLE_WEB_CLIENT_ID=$web'),
      define('GOOGLE_IOS_CLIENT_ID=$ios'),
    ].join(',');

    test('fails Archive when GoogleSignIn.generated.xcconfig is missing', () {
      // build 9 と同じ状態: URL スキームも GIDClientID も空。
      final result = run({'DART_DEFINES': defines});
      expect(result.exitCode, isNot(0));
      expect(result.stderr, contains('prepare_ios_release.sh'));
    });

    test('fails Archive when the URL scheme is for another client ID', () {
      final result = run({
        'DART_DEFINES': defines,
        'GID_CLIENT_ID': ios,
        'GID_SERVER_CLIENT_ID': web,
        'GOOGLE_REVERSED_CLIENT_ID': 'com.googleusercontent.apps.1-old',
      });
      expect(result.exitCode, isNot(0));
    });

    test('fails Archive when the iOS client ID is not a client ID', () {
      final result = run({
        'DART_DEFINES': [
          define('GOOGLE_WEB_CLIENT_ID=$web'),
          define(
            'GOOGLE_IOS_CLIENT_ID=com.narutoaii.ayg.web,com.narutoaii.ayg',
          ),
        ].join(','),
      });
      expect(result.exitCode, isNot(0));
    });

    test('passes when xcconfig matches the dart defines', () {
      final result = run({
        'DART_DEFINES': defines,
        'GID_CLIENT_ID': ios,
        'GID_SERVER_CLIENT_ID': web,
        'GOOGLE_REVERSED_CLIENT_ID': GoogleClientId.reversed(ios)!,
      });
      expect(result.exitCode, 0, reason: '${result.stderr}');
      expect(result.stdout, contains('done'));
    });

    test('Debug builds are not blocked', () {
      final result = run({'DART_DEFINES': defines, 'CONFIGURATION': 'Debug'});
      expect(result.exitCode, 0, reason: '${result.stderr}');
    });
  });

  group('configure_google_signin_ios.sh', () {
    ProcessResult configure(String iosId, String webId) {
      final dir = Directory.systemTemp.createTempSync('gsi');
      Directory('${dir.path}/tool').createSync();
      Directory('${dir.path}/ios/Flutter').createSync(recursive: true);
      File(
        'tool/configure_google_signin_ios.sh',
      ).copySync('${dir.path}/tool/configure_google_signin_ios.sh');
      final result = Process.runSync(
        '/bin/sh',
        ['${dir.path}/tool/configure_google_signin_ios.sh'],
        environment: {
          'GOOGLE_IOS_CLIENT_ID': iosId,
          'GOOGLE_WEB_CLIENT_ID': webId,
        },
      );
      final out = File(
        '${dir.path}/ios/Flutter/GoogleSignIn.generated.xcconfig',
      );
      if (out.existsSync()) {
        expect(
          out.readAsStringSync(),
          contains(
            'GOOGLE_REVERSED_CLIENT_ID=${GoogleClientId.reversed(iosId)}',
          ),
        );
      }
      dir.deleteSync(recursive: true);
      return result;
    }

    test('writes the reversed client ID', () {
      expect(configure(ios, web).exitCode, 0);
    });

    test('rejects bundle IDs and cross-project pairs', () {
      expect(
        configure('com.narutoaii.ayg.web,com.narutoaii.ayg', web).exitCode,
        isNot(0),
      );
      expect(configure(otherProjectIos, web).exitCode, isNot(0));
    });
  });
}
