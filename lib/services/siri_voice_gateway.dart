import 'package:flutter/services.dart';

import 'siri_voice_log.dart';

/// Siri が読む食品・種目の一覧と、復唱のあとに追記された登録待ち。
abstract class SiriVoiceGateway {
  Future<void> publishCatalog(String catalogJson);

  Future<String> readPending();

  Future<void> acknowledge(List<String> ids);

  /// 0件のとき Siri が残した検索語。無ければ null。
  Future<String?> readOpenSearch() async => null;

  Future<void> clearOpenSearch() async {}
}

class SiriVoiceGatewayImpl implements SiriVoiceGateway {
  SiriVoiceGatewayImpl({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(siriVoiceMethodChannel);

  final MethodChannel _channel;

  @override
  Future<void> publishCatalog(String catalogJson) async {
    await _invoke('writeCatalog', {'catalog': catalogJson});
  }

  @override
  Future<String> readPending() async {
    final raw = await _invoke('readPending');
    return raw is String ? raw : '[]';
  }

  @override
  Future<void> acknowledge(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await _invoke('acknowledge', {'ids': ids});
  }

  @override
  Future<String?> readOpenSearch() async {
    final raw = await _invoke('readOpenSearch');
    if (raw is! String || raw.trim().isEmpty) {
      return null;
    }
    return raw;
  }

  @override
  Future<void> clearOpenSearch() async {
    await _invoke('clearOpenSearch');
  }

  Future<Object?> _invoke(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
