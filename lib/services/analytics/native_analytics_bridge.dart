import 'package:flutter/services.dart';

const analyticsNativeChannelName = 'com.narutoaii.ayg/analytics_native';

class NativePendingFile {
  const NativePendingFile({required this.name, required this.json});

  final String name;
  final String json;
}

abstract class NativeAnalyticsBridge {
  Future<List<NativePendingFile>> drainPending();
  Future<void> ackPending(List<String> names);
  Future<void> setConsent(bool granted);
  Future<void> setOwnerUserId(String? userId);
  Future<void> setInstallId(String installId);
  Future<Map<String, Object?>?> appTransactionInfo();
  Future<String?> adServicesToken();
  Future<Map<String, int>> widgetConfigurations();
  Future<int> nativeDroppedOverflow();
  Future<String?> deviceModel();
}

class NoopNativeAnalyticsBridge implements NativeAnalyticsBridge {
  const NoopNativeAnalyticsBridge();

  @override
  Future<void> ackPending(List<String> names) async {}

  @override
  Future<String?> adServicesToken() async => null;

  @override
  Future<Map<String, Object?>?> appTransactionInfo() async => null;

  @override
  Future<List<NativePendingFile>> drainPending() async => const [];

  @override
  Future<int> nativeDroppedOverflow() async => 0;

  @override
  Future<void> setConsent(bool granted) async {}

  @override
  Future<void> setInstallId(String installId) async {}

  @override
  Future<void> setOwnerUserId(String? userId) async {}

  @override
  Future<Map<String, int>> widgetConfigurations() async => const {};

  @override
  Future<String?> deviceModel() async => null;
}

/// テストが、アプリ未起動で書かれたファイルを返す。
class MemoryNativeAnalyticsBridge implements NativeAnalyticsBridge {
  final List<NativePendingFile> pending = [];
  final List<String> acked = [];
  bool? consent;
  String? ownerUserId;
  String? installId;
  int droppedOverflow = 0;
  Map<String, Object?>? transaction;
  String? adsToken;
  Map<String, int> widgets = const {};

  /// true のとき保存前に落ちたことにする（ack しない確認用）。
  bool failBeforeAck = false;

  @override
  Future<void> ackPending(List<String> names) async {
    acked.addAll(names);
    pending.removeWhere((file) => names.contains(file.name));
  }

  @override
  Future<String?> adServicesToken() async => adsToken;

  @override
  Future<Map<String, Object?>?> appTransactionInfo() async => transaction;

  @override
  Future<List<NativePendingFile>> drainPending() async =>
      List<NativePendingFile>.from(pending);

  @override
  Future<int> nativeDroppedOverflow() async => droppedOverflow;

  @override
  Future<void> setConsent(bool granted) async {
    consent = granted;
  }

  @override
  Future<void> setInstallId(String id) async {
    installId = id;
  }

  @override
  Future<void> setOwnerUserId(String? userId) async {
    ownerUserId = userId;
  }

  @override
  Future<Map<String, int>> widgetConfigurations() async => widgets;

  String? model;

  @override
  Future<String?> deviceModel() async => model;
}

class MethodChannelNativeAnalyticsBridge implements NativeAnalyticsBridge {
  MethodChannelNativeAnalyticsBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(analyticsNativeChannelName);

  final MethodChannel _channel;

  @override
  Future<List<NativePendingFile>> drainPending() async {
    final raw = await _channel.invokeMethod<List<Object?>>('drainPending');
    if (raw == null) {
      return const [];
    }
    final files = <NativePendingFile>[];
    for (final item in raw) {
      if (item is! Map) {
        continue;
      }
      final name = item['name'];
      final json = item['json'];
      if (name is String && json is String) {
        files.add(NativePendingFile(name: name, json: json));
      }
    }
    return files;
  }

  @override
  Future<void> ackPending(List<String> names) async {
    await _channel.invokeMethod<void>('ackPending', {'names': names});
  }

  @override
  Future<void> setConsent(bool granted) async {
    await _channel.invokeMethod<void>('setConsent', {'granted': granted});
  }

  @override
  Future<void> setOwnerUserId(String? userId) async {
    await _channel.invokeMethod<void>('setOwnerUserId', {'userId': userId});
  }

  @override
  Future<void> setInstallId(String installId) async {
    await _channel.invokeMethod<void>('setInstallId', {'installId': installId});
  }

  @override
  Future<Map<String, Object?>?> appTransactionInfo() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'appTransactionInfo',
    );
    if (raw == null) {
      return null;
    }
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }

  @override
  Future<String?> adServicesToken() async {
    return _channel.invokeMethod<String>('adServicesToken');
  }

  @override
  Future<Map<String, int>> widgetConfigurations() async {
    final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
      'widgetConfigurations',
    );
    if (raw == null) {
      return const {};
    }
    return {
      for (final entry in raw.entries)
        if (entry.value is num) entry.key.toString(): (entry.value as num).toInt(),
    };
  }

  @override
  Future<int> nativeDroppedOverflow() async {
    final value = await _channel.invokeMethod<int>('nativeDroppedOverflow');
    return value ?? 0;
  }

  @override
  Future<String?> deviceModel() {
    return _channel.invokeMethod<String>('deviceModel');
  }
}
