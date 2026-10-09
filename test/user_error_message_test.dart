import 'dart:io';

import 'package:ayg/utils/user_error_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('network and http failures never show English text', () {
    expect(
      userErrorMessage(Exception('Bad status 500'), action: '保存'),
      '保存に失敗しました。通信状況を確認して、もう一度お試しください。（コード 500）',
    );
    for (final error in [
      const SocketException('Failed host lookup: example.supabase.co'),
      Exception('ClientException: Connection closed before full header'),
      Exception('TimeoutException after 0:00:30'),
    ]) {
      final message = userErrorMessage(error, action: '保存');
      expect(message, '保存に失敗しました。通信状況を確認して、もう一度お試しください。');
    }
  });

  test('unknown English errors become a generic Japanese message', () {
    final message = userErrorMessage(
      StateError('PostgrestException(code: 23505)'),
      action: '削除',
    );
    expect(message, '削除に失敗しました。時間をおいて、もう一度お試しください。（コード 23505）');
    expect(RegExp(r'[A-Za-z]{3,}').hasMatch(message), isFalse);
  });

  test('a Japanese reason is kept', () {
    expect(
      userErrorMessage(Exception('同じ名前のテンプレートがあります'), action: '保存'),
      '保存に失敗しました。同じ名前のテンプレートがあります',
    );
  });

  test('no screen shows a raw error after 失敗しました:', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      if (RegExp(r"失敗しました: \$\{?(error|e)\b").hasMatch(text)) {
        offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('a server rejection is not blamed on the network and keeps its code', () {
    expect(
      userErrorMessage(Exception('Bad status 400'), action: '保存'),
      '保存に失敗しました。時間をおいて、もう一度お試しください。（コード 400）',
    );
    expect(
      userErrorMessage(
        const PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505',
        ),
        action: '保存',
      ),
      '保存に失敗しました。時間をおいて、もう一度お試しください。（コード 23505）',
    );
    expect(
      userErrorMessage(
        const AuthApiException('Unacceptable audience in id_token', statusCode: '400'),
        action: 'Appleログイン',
      ),
      'Appleログインに失敗しました。時間をおいて、もう一度お試しください。（コード 400）',
    );
  });

  test('401 means log in again, but digits inside an id do not', () {
    expect(
      userErrorMessage(Exception('Bad status 401'), action: '保存'),
      '保存に失敗しました。ログインし直してから、もう一度お試しください。（コード 401）',
    );
    expect(
      userErrorMessage(
        StateError('row 7f3a401b-0000 not found'),
        action: '保存',
      ),
      '保存に失敗しました。時間をおいて、もう一度お試しください。',
    );
  });
}
