/// 画面に出すエラー文。英語の例外文（`Bad status` や `SocketException` など）は
/// そのまま見せず、何をすればよいかが分かる日本語にする。
String userErrorMessage(Object? error, {required String action}) {
  final head = '$actionに失敗しました。';
  final raw = (error ?? '').toString();
  final lower = raw.toLowerCase();
  if (_isNetwork(lower)) {
    return '$head通信状況を確認して、もう一度お試しください。';
  }
  if (_isAuth(lower)) {
    return '$headログインし直してから、もう一度お試しください。';
  }
  final japanese = japaneseDetail(raw);
  if (japanese != null) {
    return '$head$japanese';
  }
  return '$head時間をおいて、もう一度お試しください。';
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
    '401',
  ];
  return markers.any(lower.contains);
}
