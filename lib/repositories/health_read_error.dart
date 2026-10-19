import 'package:flutter/services.dart';

/// 読み取り失敗のコード。メッセージは載せない（個人情報を含み得るため）。
String healthReadErrorCode(Object error) {
  if (error is PlatformException) {
    return _safeCode(error.code, fallback: 'PlatformException');
  }
  return _safeCode(error.runtimeType.toString(), fallback: 'error');
}

String _safeCode(String raw, {required String fallback}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty || trimmed.length > 64) {
    return fallback;
  }
  if (!RegExp(r'^[A-Za-z0-9_.:-]{1,64}$').hasMatch(trimmed)) {
    return fallback;
  }
  return trimmed;
}
