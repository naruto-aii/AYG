import 'package:isar/isar.dart';

import '../../database/schemas.dart';
import 'analytics_event.dart';

/// 端末の送信待ち。上限を超えたら一番古いものから捨てる。
class AnalyticsQueue {
  AnalyticsQueue({required Isar isar, this.maxPending = defaultCap})
    : _isar = isar;

  static const int defaultCap = 20000;

  final Isar _isar;
  final int maxPending;
  int droppedOverflow = 0;

  /// [now] は最初に送ってよい時刻。`AnalyticsService` は自分の時計（本番は `DateTime.now`）を渡す。
  /// [markRetry] と同じく、渡されなければ端末の今の時刻。
  Future<void> enqueue(AnalyticsEvent event, {DateTime? now}) async {
    final row = PendingAnalyticsEvent()
      ..eventId = event.eventId
      ..userId = event.userId
      ..json = event.encode()
      ..createdAt = DateTime.now().toUtc()
      ..attempts = 0
      ..nextAttemptAt = (now ?? DateTime.now()).toUtc()
      ..quarantined = false;
    await _isar.writeTxn(() async {
      await _isar.pendingAnalyticsEvents.putByEventId(row);
      await _dropOldestIfNeeded();
    });
  }

  Future<bool> contains(String eventId) async {
    final existing = await _isar.pendingAnalyticsEvents.getByEventId(eventId);
    return existing != null;
  }

  Future<List<PendingAnalyticsEvent>> all() {
    return _isar.pendingAnalyticsEvents.where().findAll();
  }

  Future<int> count() async => (await all()).length;

  Future<void> deleteIds(Iterable<String> eventIds) async {
    await _isar.writeTxn(() async {
      for (final id in eventIds) {
        await _isar.pendingAnalyticsEvents.deleteByEventId(id);
      }
    });
  }

  Future<void> markRetry({
    required Iterable<PendingAnalyticsEvent> rows,
    required Duration wait,
    required bool countAttempt,
    DateTime? now,
  }) async {
    final stamp = (now ?? DateTime.now()).toUtc();
    await _isar.writeTxn(() async {
      for (final row in rows) {
        if (countAttempt) {
          row.attempts += 1;
        }
        row.nextAttemptAt = stamp.add(wait);
        await _isar.pendingAnalyticsEvents.put(row);
      }
    });
  }

  Future<void> quarantine(PendingAnalyticsEvent row) async {
    row.quarantined = true;
    row.attempts += 1;
    await _isar.writeTxn(() async {
      await _isar.pendingAnalyticsEvents.put(row);
    });
  }

  Future<void> assignUser(PendingAnalyticsEvent row, String userId) async {
    final event = AnalyticsEvent.decode(row.json)..userId = userId;
    row.userId = userId;
    row.json = event.encode();
    await _isar.writeTxn(() async {
      await _isar.pendingAnalyticsEvents.put(row);
    });
  }

  Future<void> clear() async {
    await _isar.writeTxn(() async {
      await _isar.pendingAnalyticsEvents.clear();
    });
  }

  Future<void> _dropOldestIfNeeded() async {
    final rows = await _isar.pendingAnalyticsEvents.where().findAll();
    if (rows.length <= maxPending) {
      return;
    }
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final extra = rows.length - maxPending;
    for (var i = 0; i < extra; i++) {
      await _isar.pendingAnalyticsEvents.delete(rows[i].id);
      droppedOverflow += 1;
    }
  }
}

Duration analyticsBackoff(int attempts) {
  var seconds = 30;
  for (var i = 1; i < attempts; i++) {
    seconds *= 2;
    if (seconds >= 3600) {
      return const Duration(hours: 1);
    }
  }
  if (seconds > 3600) {
    return const Duration(hours: 1);
  }
  return Duration(seconds: seconds);
}
