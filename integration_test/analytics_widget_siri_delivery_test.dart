import 'dart:convert';

import 'package:ayg/services/analytics/native_analytics_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../test/helpers/analytics_test_support.dart';
import '../test/helpers/isar_test_helper.dart';

/// アプリを起動していない間にウィジェットと Siri が残した操作が、
/// 次の起動の取り込みで届く。この環境にはシミュレーターもローカルの
/// Supabase も無いので、同じ手順を端末内の待ち行列と偽の送信先で確かめる。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('widget and siri actions arrive on the next launch', () async {
    final isarHarness = await setUpIsarHarness();
    final pressedAt = DateTime.parse('2026-10-07T08:15:00+09:00');
    final files = [
      _pending(
        name: 'widget_tap',
        origin: 'home_widget',
        stream: 'widget',
        when: pressedAt,
        props: {
          'surface': 'home',
          'slot': 0,
          'kind': 'meal',
          'result': 'unpaid',
        },
      ),
      _pending(
        name: 'widget_tap',
        origin: 'lock_widget',
        stream: 'widget',
        when: pressedAt,
        props: {
          'surface': 'lock',
          'slot': 1,
          'kind': 'meal',
          'result': 'unassigned',
        },
      ),
      _pending(
        name: 'siri_request_finished',
        origin: 'siri',
        stream: 'siri',
        when: pressedAt,
        props: {
          'request_id': 'spoken',
          'status': 'blocked',
          'stop_reason': 'unpaid',
          'prompts_count': 0,
          'duration_ms': 1,
          'items_count': 0,
        },
      ),
    ];
    final bridge = MemoryNativeAnalyticsBridge()..pending.addAll(files);
    final analytics = await AnalyticsHarness.open(
      isar: isarHarness.isar,
      bridge: bridge,
    );
    await analytics.service.grantConsent(surface: 'first_launch');
    await analytics.service.setCurrentUser(
      '11111111-1111-4111-8111-111111111111',
    );
    await analytics.service.importNativePending();
    await analytics.service.flush();

    expect(bridge.pending, isEmpty);
    expect(bridge.acked, hasLength(3));
    for (final origin in ['home_widget', 'lock_widget', 'siri']) {
      final row = analytics.holding.delivered.singleWhere(
        (item) => item['origin'] == origin,
      );
      expect(
        DateTime.parse(row['occurred_at'] as String).toUtc(),
        pressedAt.toUtc(),
      );
    }
    final stored = await analytics.queue.all();
    expect(stored, isEmpty);
    final nativeIds = analytics.holding.delivered
        .where(
          (row) =>
              row['origin'] == 'home_widget' ||
              row['origin'] == 'lock_widget' ||
              row['origin'] == 'siri',
        )
        .map((row) => row['event_id'])
        .toSet();
    expect(nativeIds, hasLength(3));
  });
}

NativePendingFile _pending({
  required String name,
  required String origin,
  required String stream,
  required DateTime when,
  required Map<String, Object?> props,
}) {
  final id = const Uuid().v4();
  return NativePendingFile(
    name: '$id.json',
    json: jsonEncode({
      'event_id': id,
      'event_name': name,
      'occurred_at': when.toIso8601String(),
      'origin': origin,
      'install_id': '',
      'stream': stream,
      'sequence_number': 1,
      'app_version': '1.0.0',
      'app_build': '1',
      'schema_version': 1,
      'props': props,
      'owner_user_id': '11111111-1111-4111-8111-111111111111',
    }),
  );
}
