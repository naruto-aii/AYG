import 'dart:convert';

import 'package:ayg/services/analytics/analytics_event.dart';
import 'package:ayg/services/analytics/native_analytics_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'helpers/analytics_test_support.dart';
import 'helpers/isar_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ack happens after save, a crash keeps the file, and the press time stays',
    () async {
      final isarHarness = await setUpIsarHarness();
      final pressedAt = DateTime.utc(2026, 10, 7, 1, 2, 3);
      final eventId = const Uuid().v4();
      final file = _file(eventId, pressedAt);
      final crashing = _CrashOnAck()..pending.add(file);
      final crashed = await AnalyticsHarness.open(
        isar: isarHarness.isar,
        bridge: crashing,
      );
      await crashed.service.grantConsent(surface: 'first_launch');
      await crashed.service.setCurrentUser(
        '11111111-1111-4111-8111-111111111111',
      );
      await expectLater(
        crashed.service.importNativePending(),
        throwsStateError,
      );
      expect(crashing.pending, isNotEmpty);
      expect(crashing.acked, isEmpty);
      expect(await crashed.queue.contains(eventId), isTrue);
      final stored = AnalyticsEvent.decode(
        (await crashed.queue.all())
            .singleWhere((row) => row.eventId == eventId)
            .json,
      );
      expect(stored.occurredAt.toUtc(), pressedAt);
      expect(stored.origin, 'lock_widget');

      final recovering = MemoryNativeAnalyticsBridge()..pending.add(file);
      final next = await AnalyticsHarness.open(
        isar: isarHarness.isar,
        bridge: recovering,
      );
      await next.service.grantConsent(surface: 'first_launch');
      await next.service.importNativePending();
      expect(recovering.acked, [file.name]);
      expect(recovering.pending, isEmpty);
      expect(
        (await next.queue.all()).where((row) => row.eventId == eventId),
        hasLength(1),
      );

      recovering.pending.add(file);
      await next.service.importNativePending();
      expect(
        (await next.queue.all()).where((row) => row.eventId == eventId),
        hasLength(1),
      );
    },
  );
}

NativePendingFile _file(String eventId, DateTime pressedAt) {
  return NativePendingFile(
    name: '$eventId.json',
    json: jsonEncode({
      'event_id': eventId,
      'event_name': 'widget_tap',
      'occurred_at': pressedAt.toIso8601String(),
      'origin': 'lock_widget',
      'install_id': '',
      'session_id': null,
      'stream': 'widget',
      'sequence_number': 4,
      'app_version': '1.0.0',
      'app_build': '1',
      'schema_version': 1,
      'props': {
        'surface': 'lock',
        'slot': 1,
        'kind': 'meal',
        'result': 'unpaid',
      },
      'owner_user_id': '11111111-1111-4111-8111-111111111111',
    }),
  );
}

class _CrashOnAck extends MemoryNativeAnalyticsBridge {
  @override
  Future<void> ackPending(List<String> names) async {
    throw StateError('crashed before ack');
  }
}
