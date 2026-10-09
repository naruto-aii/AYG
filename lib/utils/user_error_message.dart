import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthException, FunctionException, PostgrestException;

/// 画面に出すエラー文。英語の例外文（`Bad status` や `SocketException` など）は
/// そのまま見せず、何をすればよいかが分かる日本語にする。
///
/// 原因を後から追えるよう、数字のコード（HTTP の状態や DB のエラー番号）が
/// 分かるときは末尾に「（コード 500）」の形で添え、元の例外文はログに残す。
String userErrorMessage(Object? error, {required String action}) {
  final head = '$actionに失敗しました。';
  final raw = (error ?? '').toString();
  final lower = raw.toLowerCase();
  final status = _httpStatus(error, lower);
  final code = _codeSuffix(error, raw, status);
  debugPrint('[AYG] $action failed: $raw');
  if (status == 401 || _isAuth(lower)) {
    return '${head}ログインし直してから、もう一度お試しください。$code';
  }
  final serverRejected =
      status != null && status >= 400 && status < 500 && status != 408 && status != 429;
  if (!serverRejected && _isNetwork(lower)) {
    return '$head通信状況を確認して、もう一度お試しください。$code';
  }
  final japanese = japaneseDetail(raw);
  if (japanese != null) {
    return '$head$japanese';
  }
  return '$head時間をおいて、もう一度お試しください。$code';
}

int? _httpStatus(Object? error, String lower) {
  int? three(String? value) {
    final parsed = int.tryParse(value ?? '');
    return parsed != null && parsed >= 100 && parsed <= 599 ? parsed : null;
  }

  if (error is PostgrestException) {
    final fromCode = three(error.code);
    if (fromCode != null) {
      return fromCode;
    }
  }
  if (error is AuthException) {
    final fromStatus = three(error.statusCode);
    if (fromStatus != null) {
      return fromStatus;
    }
  }
  if (error is FunctionException) {
    return three('${error.status}');
  }
  final match = RegExp(
    r'(?:bad status|status code|statuscode|status)[^0-9]{0,3}(\d{3})\b',
  ).firstMatch(lower);
  return three(match?.group(1));
}

/// 数字だけのコード（英字の単語を画面に出さない）。DB の SQLSTATE（23505 など）か HTTP 状態。
String _codeSuffix(Object? error, String raw, int? status) {
  String? sqlState;
  final sqlPattern = RegExp(r'^[0-9]{2}[0-9A-Z]{3}$');
  if (error is PostgrestException && sqlPattern.hasMatch(error.code ?? '')) {
    sqlState = error.code;
  } else {
    final match = RegExp(r'code:\s*([0-9]{2}[0-9A-Z]{3})\b').firstMatch(raw);
    sqlState = match?.group(1);
  }
  final code = sqlState ?? (status == null ? null : '$status');
  return code == null ? '' : '（コード $code）';
}

/// 例外文がもともと日本語の案内なら、その文だけを返す。英語が混ざるなら null。
String? japaneseDetail(String raw) {
  var text = raw.trim();
  for (final prefix in const [
    'Exception: ',
    'FormatException: ',
    'StateError: ',
    'Bad state: ',
  ]) {
    if (text.startsWith(prefix)) {
      text = text.substring(prefix.length).trim();
    }
  }
  if (text.isEmpty) {
    return null;
  }
  final hasJapanese = RegExp(r'[\u3040-\u30ff\u4e00-\u9fff]').hasMatch(text);
  final hasLatinWord = RegExp(r'[A-Za-z]{3,}').hasMatch(text);
  if (!hasJapanese || hasLatinWord) {
    return null;
  }
  return text;
}

bool _isNetwork(String lower) {
  const markers = [
    'socketexception',
    'failed host lookup',
    'clientexception',
    'connection closed',
    'connection refused',
    'connection reset',
    'network',
    'timeout',
    'timed out',
    'handshakeexception',
    'bad status',
    'status code',
    'xmlhttprequest',
  ];
  return markers.any(lower.contains);
}

bool _isAuth(String lower) {
  const markers = [
    'authexception',
    'jwt',
    'not authenticated',
    'unauthorized',
  ];
  return markers.any(lower.contains);
}
