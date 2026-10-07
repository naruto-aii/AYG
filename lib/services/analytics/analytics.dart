import 'dart:async';

import 'analytics_service.dart';

/// 画面とコントローラーから使う入口。未初期化のときは何もしない。
abstract final class Analytics {
  static AnalyticsService? service;

  static void emit(
    String name, [
    Map<String, Object?> props = const {},
    String? origin,
    String? eventId,
  ]) {
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
