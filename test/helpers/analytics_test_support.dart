import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/analytics/analytics_queue.dart';
import 'package:ayg/services/analytics/analytics_sender.dart';
import 'package:ayg/services/analytics/analytics_service.dart';
import 'package:ayg/services/analytics/native_analytics_bridge.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HoldingTransport implements AnalyticsTransport {
  AnalyticsSendResult next = const AnalyticsSendResult.success();
  final List<Map<String, dynamic>> delivered = [];

  @override
  Future<AnalyticsSendResult> send(List<Map<String, dynamic>> rows) async {
    final result = next;
    if (result.succeeded) {
      delivered.addAll(rows);
    }
    return result;
  }
}

class AnalyticsHarness {
  AnalyticsHarness({
    required this.service,
    required this.queue,
    required this.transport,
    required this.bridge,
    required this.preferences,
  });

  final AnalyticsService service;
  final AnalyticsQueue queue;
  final AnalyticsTransport transport;
  final MemoryNativeAnalyticsBridge bridge;
  final SharedPreferences preferences;

  HoldingTransport get holding => transport as HoldingTransport;

  static Future<AnalyticsHarness> open({
    required Isar isar,
    int maxPending = AnalyticsQueue.defaultCap,
    DateTime Function()? clock,
    AnalyticsTransport? transport,
    MemoryNativeAnalyticsBridge? bridge,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final resolved = transport ?? HoldingTransport();
    final resolvedBridge = bridge ?? MemoryNativeAnalyticsBridge();
    final queue = AnalyticsQueue(isar: isar, maxPending: maxPending);
    final service = AnalyticsService(
      preferences: preferences,
      queue: queue,
      transport: resolved,
      bridge: resolvedBridge,
      clock: clock ?? () => DateTime.utc(2027, 1, 1),
      appVersion: '1.0.0',
      appBuild: '1',
      osVersion: '18.0',
      deviceModel: 'iPhone15,2',
      locale: 'ja_JP',
      timeZone: 'Asia/Tokyo',
    );
    Analytics.service = service;
    return AnalyticsHarness(
      service: service,
      queue: queue,
      transport: resolved,
      bridge: resolvedBridge,
      preferences: preferences,
    );
  }

  int count(String name) {
    final current = transport;
    final rows = current is HoldingTransport
        ? current.delivered
        : const <Map<String, dynamic>>[];
    return rows.where((row) => row['event_name'] == name).length;
  }
}
