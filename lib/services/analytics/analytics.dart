import 'dart:async';

import 'analytics_service.dart';

/// 画面とコントローラーから使う入口。未初期化のときは何もしない。
abstract final class Analytics {
  static AnalyticsService? service;

  /// テストが送信内容を見るための入口。本番は null。
  static void Function(String name, Map<String, Object?> props)? onEmitForTest;

  static void emit(
    String name, [
    Map<String, Object?> props = const {},
    String? origin,
    String? eventId,
  ]) {
    onEmitForTest?.call(name, props);
    final current = service;
    if (current == null) {
      return;
    }
    unawaited(current.track(name, props, origin, eventId));
  }

  static Future<void> emitAndWait(
    String name, [
    Map<String, Object?> props = const {},
    String? origin,
  ]) async {
    final current = service;
    if (current == null) {
      return;
    }
    await current.track(name, props, origin);
  }
}
