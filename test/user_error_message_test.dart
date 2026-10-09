import 'dart:io';

import 'package:ayg/utils/user_error_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('network and http failures never show English text', () {
    for (final error in [
      Exception('Bad status 500'),
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
    expect(message, '削除に失敗しました。時間をおいて、もう一度お試しください。');
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
}
