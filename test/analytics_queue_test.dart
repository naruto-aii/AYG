import 'package:ayg/database/isar_service.dart';
import 'package:ayg/models/sync_failure.dart';
import 'package:ayg/repositories/sync_step_runner.dart';
import 'package:ayg/services/analytics/analytics.dart';
import 'package:ayg/services/analytics/analytics_event.dart';
import 'package:ayg/services/analytics/analytics_queue.dart';
import 'package:ayg/services/analytics/analytics_sender.dart';
import 'package:ayg/services/analytics/supabase_analytics_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ayg/services/isar/local_user_data_clearer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import 'helpers/analytics_test_support.dart';
import 'helpers/isar_test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default cap keeps the oldest 20000', () {
    expect(AnalyticsQueue.defaultCap, 20000);
  });

  test(
    'network timeout 500 429 and 401 stay queued then deliver once',
    () async {
      final isarHarness = await setUpIsarHarness();
      final clock = _MutableClock(DateTime.utc(2026, 10, 7));
      final analytics = await AnalyticsHarness.open(
        isar: isarHarness.isar,
        clock: () => clock.value,
      );
      await analytics.service.grantConsent(surface: 'first_launch');
      await analytics.service.setCurrentUser(
        '11111111-1111-4111-8111-111111111111',
      );
      await analytics.service.track('app_error', {
        'error_type': 'StateError',
        'where': 'queue',
        'fatal': false,
      });
      await analytics.service.settled;

      for (final result in [
        const AnalyticsSendResult(),
        const AnalyticsSendResult(timedOut: true),
        const AnalyticsSendResult(statusCode: 500),
        const AnalyticsSendResult(statusCode: 429),
        const AnalyticsSendResult(statusCode: 401),
      ]) {
        analytics.holding.next = result;
        await analytics.service.flush();
        expect(await analytics.queue.count(), greaterThan(0));
        expect(
          analytics.holding.delivered.where(
            (row) => row['event_name'] == 'app_error',
          ),
          isEmpty,
        );
      }

      clock.value = DateTime.utc(2026, 10, 8);
      analytics.holding.next = const AnalyticsSendResult.success();
      await analytics.service.flush();
      final sent = analytics.holding.delivered
          .where((row) => row['event_name'] == 'app_error')
          .toList();
      expect(sent, hasLength(1));
      expect(await analytics.queue.count(), 0);
      await analytics.service.flush();
      expect(
        analytics.holding.delivered.where(
          (row) => row['event_name'] == 'app_error',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'one bad row is quarantined and the others are delivered once',
    () async {
      final isarHarness = await setUpIsarHarness();
      const badId = '22222222-2222-4222-8222-222222222222';
      final transport = _BadRowTransport(badId);
      final analytics = await AnalyticsHarness.open(
        isar: isarHarness.isar,
        transport: transport,
      );
      await analytics.service.grantConsent(surface: 'first_launch');
      await analytics.service.setCurrentUser(
        '11111111-1111-4111-8111-111111111111',
      );
      await analytics.service.track('logout', {'forced': false});
      await analytics.service.track('logout', {'forced': true}, null, badId);
      await analytics.service.track('contact_tap', {'channel': 'email'});
      await analytics.service.settled;
      await analytics.service.flush();

      final good = transport.delivered
          .where((row) => row['event_id'] != badId)
          .toList();
      final ids = good.map((row) => row['event_id']).toList();
      expect(ids.toSet().length, ids.length);
      expect(
        transport.delivered.any((row) => row['event_id'] == badId),
        isFalse,
      );
      final left = await analytics.queue.all();
      expect(left.map((row) => row.eventId), [badId]);
      expect(left.single.quarantined, isTrue);

      await analytics.service.reportHealth(force: true);
      await analytics.service.flush();
      final health = transport.delivered
          .where((row) => row['event_name'] == 'analytics_queue_health')
          .last;
      expect((health['props'] as Map)['quarantined_count'], 1);
    },
  );

  test('reopen, clearAll, and sync failure keep the queue', () async {
    final isarHarness = await IsarTestHarness.create();
    final analytics = await AnalyticsHarness.open(isar: isarHarness.isar);
    await analytics.service.grantConsent(surface: 'first_launch');
    await analytics.service.setCurrentUser(
      '11111111-1111-4111-8111-111111111111',
    );
    final id = const Uuid().v4();
    await analytics.service.track(
      'app_open',
      {'launch_source': 'icon', 'previous_session_abnormal_end': false},
      null,
      id,
    );
    await analytics.service.settled;
    expect(await analytics.queue.contains(id), isTrue);

    final clearer = LocalUserDataClearer(
      isar: isarHarness.isar,
      userRepository: isarHarness.userRepository,
      settingsRepository: isarHarness.settingsRepository,
      foodRepository: isarHarness.foodRepository,
      exerciseRepository: isarHarness.exerciseRepository,
      alcoholRepository: isarHarness.alcoholRepository,
      weightRepository: isarHarness.weightRepository,
      savedFoodRepository: isarHarness.savedFoodRepository,
      mealTemplateRepository: isarHarness.mealTemplateRepository,
      workoutTemplateRepository: isarHarness.workoutTemplateRepository,
    );
    await clearer.clearAll();
    expect(await analytics.queue.contains(id), isTrue);

    try {
      await runSyncStep<void>(
        step: SyncStep.fetchFoodEntries,
        repository: 'test',
        tableName: 'food_entries',
        operation: 'pull',
        action: () async => throw Exception('down'),
      );
    } on SyncStepException {
      // 同期失敗は送信待ちを消さない。
    }
    await analytics.service.settled;
    expect(await analytics.queue.contains(id), isTrue);

    final directory = isarHarness.directory.path;
    Analytics.service = null;
    await IsarService.close();
    final reopened = await IsarService.openForTesting(directory);
    final again = AnalyticsQueue(isar: reopened);
    expect(await again.contains(id), isTrue);
    await IsarService.close();
    if (await isarHarness.directory.exists()) {
      await isarHarness.directory.delete(recursive: true);
    }
  });

  test('overflow drops the oldest and counts it', () async {
    final isarHarness = await setUpIsarHarness();
    final queue = AnalyticsQueue(isar: isarHarness.isar, maxPending: 2);
    for (var i = 0; i < 3; i++) {
      await queue.enqueue(_event('id-$i'));
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    final left = await queue.all();
    expect(left, hasLength(2));
    expect(left.map((row) => row.eventId), isNot(contains('id-0')));
    expect(queue.droppedOverflow, 1);
  });

  test('PGRST205 holds the queue instead of retrying immediately', () async {
    expect(
      analyticsStatusForPostgrest(
        const PostgrestException(message: 'missing', code: 'PGRST205'),
      ),
      404,
    );
    expect(
      analyticsStatusForPostgrest(
        const PostgrestException(message: 'missing', code: '404'),
      ),
      404,
    );

    final isarHarness = await setUpIsarHarness();
    final clock = _MutableClock(DateTime.utc(2027, 1, 1));
    final transport = _FixedTransport(
      const AnalyticsSendResult(statusCode: 404),
    );
    final analytics = await AnalyticsHarness.open(
      isar: isarHarness.isar,
      clock: () => clock.value,
      transport: transport,
    );
    await analytics.service.grantConsent(surface: 'first_launch');
    await analytics.service.setCurrentUser(
      '11111111-1111-4111-8111-111111111111',
    );
    await analytics.service.track('logout', {'forced': false});
    await analytics.service.track('logout', {'forced': true});
    await analytics.service.settled;

    await analytics.service.flush();
    expect(transport.calls, 1);
    await analytics.service.flush();
    expect(transport.calls, 1);
    final held = await analytics.queue.all();
    expect(held.length, greaterThanOrEqualTo(2));
    expect(held.every((row) => row.quarantined), isFalse);
    expect(held.map((row) => row.attempts).reduce((a, b) => a > b ? a : b), 1);

    for (var i = 0; i < analyticsTableMissingAttemptCap; i++) {
      clock.value = clock.value.add(analyticsTableMissingHold);
      await analytics.service.flush();
    }
    final done = await analytics.queue.all();
    expect(done.every((row) => row.quarantined), isTrue);
    final callsAfterCap = transport.calls;
    clock.value = clock.value.add(const Duration(days: 30));
    await analytics.service.flush();
    expect(transport.calls, callsAfterCap);
  });
}

class _FixedTransport implements AnalyticsTransport {
  _FixedTransport(this.result);

  final AnalyticsSendResult result;
  var calls = 0;

  @override
  Future<AnalyticsSendResult> send(List<Map<String, dynamic>> rows) async {
    calls += 1;
    return result;
  }
}

AnalyticsEvent _event(String id) {
  return AnalyticsEvent(
    eventId: id,
    eventName: 'app_open',
    occurredAt: DateTime.utc(2026, 10, 7),
    origin: 'app',
    installId: '33333333-3333-4333-8333-333333333333',
    sessionId: null,
    stream: 'app',
    sequenceNumber: 1,
    appVersion: '1.0.0',
    appBuild: '1',
    osVersion: null,
    deviceModel: null,
    locale: null,
    timeZone: null,
    schemaVersion: 1,
    props: const {
      'launch_source': 'icon',
      'previous_session_abnormal_end': false,
    },
    userId: '11111111-1111-4111-8111-111111111111',
  );
}

class _MutableClock {
  _MutableClock(this.value);

  DateTime value;
}

class _BadRowTransport implements AnalyticsTransport {
  _BadRowTransport(this.badId);

  final String badId;
  final List<Map<String, dynamic>> delivered = [];

  @override
  Future<AnalyticsSendResult> send(List<Map<String, dynamic>> rows) async {
    if (rows.any((row) => row['event_id'] == badId)) {
      return const AnalyticsSendResult(statusCode: 400);
    }
    delivered.addAll(rows);
    return const AnalyticsSendResult.success();
  }
}
