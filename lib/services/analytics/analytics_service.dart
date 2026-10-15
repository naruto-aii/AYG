import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../database/schemas.dart';
import 'analytics_event.dart';
import 'analytics_queue.dart';
import 'analytics_sender.dart';
import 'app_event_retention.dart';
import 'event_names.dart';
import 'native_analytics_bridge.dart';

const analyticsPolicyVersion = '2026-10-07';
const _consentKey = 'analytics_consent';
const _installKey = 'analytics_install_id';
const _sequenceKey = 'analytics_sequence_app';
const _sessionIdKey = 'analytics_session_id';
const _sessionNumberKey = 'analytics_session_number';
const _lastBackgroundKey = 'analytics_last_background_ms';
const _foregroundDirtyKey = 'analytics_foreground_dirty';
const _versionKey = 'analytics_last_app_version';
const _osKey = 'analytics_last_os_version';
const _droppedKey = 'analytics_dropped_overflow';
const _enqueueFailKey = 'analytics_enqueue_failures';
const _lastSuccessKey = 'analytics_last_success_ms';
const _healthDayKey = 'analytics_health_day';
const _consentUploadKey = 'analytics_consent_pending';
const _sessionStartKey = 'analytics_session_started_ms';
const _eventsInSessionKey = 'analytics_events_in_session';
const _screensInSessionKey = 'analytics_screens_in_session';

/// 同意、連番、送信待ち、送信。画面描画は止めない。
class AnalyticsService {
  AnalyticsService({
    required SharedPreferences preferences,
    required AnalyticsQueue queue,
    required AnalyticsTransport transport,
    required NativeAnalyticsBridge bridge,
    DateTime Function()? clock,
    Uuid? uuid,
    this.appVersion = '1.0.0',
    this.appBuild = '1',
    this.osVersion,
    this.deviceModel,
    this.locale,
    this.timeZone,
    this.onUnauthorized,
    this.onConsentRow,
  }) : _preferences = preferences,
       _queue = queue,
       _transport = transport,
       _bridge = bridge,
       _clock = clock ?? DateTime.now,
       _uuid = uuid ?? const Uuid();

  final SharedPreferences _preferences;
  final AnalyticsQueue _queue;
  final AnalyticsTransport _transport;
  final NativeAnalyticsBridge _bridge;
  final DateTime Function() _clock;
  final Uuid _uuid;
  final String appVersion;
  final String appBuild;
  final String? osVersion;
  String? deviceModel;
  final String? locale;
  final String? timeZone;
  final Future<void> Function()? onUnauthorized;
  final Future<void> Function(Map<String, Object?> row)? onConsentRow;

  final List<Future<void>> _inFlight = [];
  String? currentUserId;
  bool foreground = true;
  String? currentScreen;
  DateTime? currentScreenSince;
  int enqueueFailures = 0;
  bool _flushing = false;

  AnalyticsQueue get queue => _queue;
  NativeAnalyticsBridge get bridge => _bridge;

  bool get consented => _preferences.getString(_consentKey) == 'granted';

  bool get consentDecided => _preferences.getString(_consentKey) != null;

  Future<void> get settled => _waitInFlight();

  Future<String> ensureInstallId() async {
    final existing = _preferences.getString(_installKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final created = _uuid.v4();
    await _preferences.setString(_installKey, created);
    return created;
  }

  Future<void> grantConsent({required String surface}) async {
    await _preferences.setString(_consentKey, 'granted');
    final id = await ensureInstallId();
    await _bridge.setConsent(true);
    await _bridge.setInstallId(id);
    await _rememberConsentUpload(consented: true, surface: surface);
    await track('analytics_consent_shown', {
      'policy_version': analyticsPolicyVersion,
      'surface': surface,
    });
  }

  Future<void> declineConsent({required String surface}) async {
    await _preferences.setString(_consentKey, 'denied');
    await _bridge.setConsent(false);
    await _queue.clear();
    await _clearNativePending();
    await _rememberConsentUpload(consented: false, surface: surface);
  }

  Future<void> revokeConsent() async {
    await track('local_data_cleared', {
      'reason': 'other',
      'pending_records_count': 0,
    });
    await flush(budget: const Duration(seconds: 2));
    await _preferences.setString(_consentKey, 'denied');
    await _bridge.setConsent(false);
    await _queue.clear();
    await _clearNativePending();
    await _rememberConsentUpload(consented: false, surface: 'settings');
  }

  /// 同意が無い操作は端末にもためない。
  Future<void> track(
    String name, [
    Map<String, Object?> props = const {},
    String? origin,
    String? eventId,
    DateTime? occurredAt,
    String? stream,
    int? sequenceNumber,
    String? presetInstallId,
  ]) {
    final future = _track(
      name,
      props,
      origin: origin,
      eventId: eventId,
      occurredAt: occurredAt,
      stream: stream,
      sequenceNumber: sequenceNumber,
      presetInstallId: presetInstallId,
    );
    _inFlight.add(future);
    future.whenComplete(() => _inFlight.remove(future));
    return future;
  }

  Future<void> _track(
    String name,
    Map<String, Object?> props, {
    String? origin,
    String? eventId,
    DateTime? occurredAt,
    String? stream,
    int? sequenceNumber,
    String? presetInstallId,
  }) async {
    if (!consented) {
      return;
    }
    if (!AnalyticsEventNames.all.contains(name)) {
      assert(false, 'unknown analytics event $name');
      return;
    }
    final clean = _sanitize(name, props);
    final resolvedStream = stream ?? 'app';
    final sequence = sequenceNumber ?? await _nextSequence();
    final event = AnalyticsEvent(
      eventId: eventId ?? _uuid.v4(),
      eventName: name,
      occurredAt: occurredAt ?? _clock().toUtc(),
      origin: origin ?? 'app',
      installId: presetInstallId ?? await ensureInstallId(),
      sessionId: _preferences.getString(_sessionIdKey),
      stream: resolvedStream,
      sequenceNumber: sequence,
      appVersion: appVersion,
      appBuild: appBuild,
      osVersion: osVersion,
      deviceModel: deviceModel,
      locale: locale,
      timeZone: timeZone,
      schemaVersion: 1,
      props: clean,
      userId: currentUserId,
    );
    await _save(event);
    final counted = _preferences.getInt(_eventsInSessionKey) ?? 0;
    await _preferences.setInt(_eventsInSessionKey, counted + 1);
    if (foreground && await _readyCount() >= 20) {
      unawaited(flush());
    }
  }

  Future<void> _save(AnalyticsEvent event) async {
    try {
      await _queue.enqueue(event);
    } catch (error, stackTrace) {
      debugPrint('[AYG] analytics enqueue failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      try {
        await _queue.enqueue(event);
      } catch (again, againStack) {
        enqueueFailures += 1;
        await _preferences.setInt(
          _enqueueFailKey,
          (_preferences.getInt(_enqueueFailKey) ?? 0) + 1,
        );
        debugPrint('[AYG] analytics enqueue retry failed: $again');
        debugPrintStack(stackTrace: againStack);
      }
    }
  }

  Future<void> importNativePending() async {
    if (!consented) {
      return;
    }
    final files = await _bridge.drainPending();
    final saved = <String>[];
    for (final file in files) {
      try {
        final event = AnalyticsEvent.decode(file.json);
        if (await _queue.contains(event.eventId)) {
          saved.add(file.name);
          continue;
        }
        final install = event.installId.isEmpty
            ? await ensureInstallId()
            : event.installId;
        final stamped = AnalyticsEvent(
          eventId: event.eventId,
          eventName: event.eventName,
          occurredAt: event.occurredAt,
          origin: event.origin,
          installId: install,
          sessionId: event.sessionId,
          stream: event.stream,
          sequenceNumber: event.sequenceNumber,
          appVersion: event.appVersion.isEmpty ? appVersion : event.appVersion,
          appBuild: event.appBuild.isEmpty ? appBuild : event.appBuild,
          osVersion: event.osVersion ?? osVersion,
          deviceModel: event.deviceModel ?? deviceModel,
          locale: event.locale ?? locale,
          timeZone: event.timeZone ?? timeZone,
          schemaVersion: event.schemaVersion,
          props: _sanitize(event.eventName, event.props),
          userId: event.userId ?? currentUserId,
        );
        await _queue.enqueue(stamped);
        saved.add(file.name);
      } catch (error, stackTrace) {
        debugPrint('[AYG] analytics native import failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    if (saved.isNotEmpty) {
      await _bridge.ackPending(saved);
    }
  }

  Future<FlushReport> flush({Duration? budget}) async {
    if (_flushing || !consented) {
      return const FlushReport(sent: 0);
    }
    _flushing = true;
    final started = _clock();
    var sent = 0;
    try {
      await _uploadConsent();
      while (true) {
        if (budget != null && _clock().difference(started) > budget) {
          break;
        }
        final batch = await _nextBatch();
        if (batch.isEmpty) {
          break;
        }
        final expired = <PendingAnalyticsEvent>[];
        final fresh = <PendingAnalyticsEvent>[];
        for (final row in batch) {
          final occurredAt = AnalyticsEvent.decode(row.json).occurredAt;
          if (appEventMonthIsAggregated(occurredAt, _clock())) {
            expired.add(row);
          } else {
            fresh.add(row);
          }
        }
        if (expired.isNotEmpty) {
          await _queue.deleteIds(expired.map((row) => row.eventId));
        }
        if (fresh.isEmpty) {
          continue;
        }
        final sentNow = await _sendBatch(fresh);
        if (sentNow < 0) {
          break;
        }
        sent += sentNow;
      }
    } finally {
      _flushing = false;
    }
    return FlushReport(sent: sent);
  }

  Future<int> _sendBatch(List<PendingAnalyticsEvent> batch) async {
    for (final row in batch) {
      if ((row.userId == null || row.userId!.isEmpty) &&
          currentUserId != null) {
        await _queue.assignUser(row, currentUserId!);
      }
    }
    final ready = <PendingAnalyticsEvent>[];
    for (final row in batch) {
      final owner = row.userId;
      if (owner == null || owner.isEmpty) {
        continue;
      }
      if (currentUserId != null && owner != currentUserId) {
        continue;
      }
      ready.add(row);
    }
    if (ready.isEmpty) {
      return 0;
    }
    final rows = [
      for (final row in ready)
        AnalyticsEvent.decode(row.json).toRow(clientSentAt: _clock().toUtc()),
    ];
    AnalyticsSendResult result;
    try {
      result = await _transport.send(rows);
    } catch (error, stackTrace) {
      debugPrint('[AYG] analytics send failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      result = const AnalyticsSendResult();
    }
    if (result.succeeded) {
      await _queue.deleteIds([
        ...ready.map((row) => row.eventId),
        ...result.rejectedEventIds,
      ]);
      await _preferences.setInt(
        _lastSuccessKey,
        _clock().toUtc().millisecondsSinceEpoch,
      );
      return ready.length;
    }
    if (result.unauthorized) {
      final refresh = onUnauthorized;
      if (refresh != null) {
        try {
          await refresh();
        } catch (error, stackTrace) {
          debugPrint('[AYG] analytics session refresh failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
      }
      await _queue.markRetry(
        rows: ready,
        wait: const Duration(seconds: 30),
        countAttempt: false,
        now: _clock(),
      );
      return 0;
    }
    if (result.tableMissing) {
      await _queue.markRetry(
        rows: ready,
        wait: analyticsTableMissingHold,
        countAttempt: true,
        now: _clock(),
      );
      return -1;
    }
    if (result.dataError) {
      if (ready.length == 1) {
        debugPrint(
          '[AYG] analytics dropped invalid event ${ready.single.eventId}',
        );
        await _queue.quarantine(ready.single);
        return 0;
      }
      final mid = ready.length ~/ 2;
      final first = await _sendBatch(ready.sublist(0, mid));
      final second = await _sendBatch(ready.sublist(mid));
      return first + second;
    }
    final attempts = ready
        .map((row) => row.attempts)
        .fold<int>(1, (a, b) => a > b ? a : b);
    await _queue.markRetry(
      rows: ready,
      wait: analyticsBackoff(attempts + 1),
      countAttempt: true,
      now: _clock(),
    );
    return 0;
  }

  Future<List<PendingAnalyticsEvent>> _nextBatch() async {
    final now = _clock().toUtc();
    final rows = await _queue.all();
    final ready = rows.where((row) {
      if (row.quarantined) {
        return false;
      }
      if (row.nextAttemptAt.isAfter(now)) {
        return false;
      }
      final owner = row.userId;
      if (owner != null &&
          owner.isNotEmpty &&
          currentUserId != null &&
          owner != currentUserId) {
        return false;
      }
      if ((owner == null || owner.isEmpty) && currentUserId == null) {
        return false;
      }
      return true;
    }).toList();
    ready.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (ready.length > 100) {
      return ready.sublist(0, 100);
    }
    return ready;
  }

  Future<int> _readyCount() async {
    return (await _nextBatch()).length;
  }

  Future<void> reportHealth({bool force = false}) async {
    final today = _clock().toUtc().toIso8601String().substring(0, 10);
    final seen = _preferences.getString(_healthDayKey);
    if (!force && seen == today) {
      return;
    }
    final rows = await _queue.all();
    final pending = rows.where((row) => !row.quarantined).toList();
    final oldest = pending.isEmpty
        ? 0
        : _clock()
              .toUtc()
              .difference(
                pending
                    .map((row) => row.createdAt)
                    .reduce((a, b) => a.isBefore(b) ? a : b),
              )
              .inSeconds;
    final lastSuccess = _preferences.getInt(_lastSuccessKey);
    final dropped =
        (_preferences.getInt(_droppedKey) ?? 0) + _queue.droppedOverflow;
    await _preferences.setInt(_droppedKey, dropped);
    _queue.droppedOverflow = 0;
    final nativeFiles = await _bridge.drainPending();
    await track('analytics_queue_health', {
      'pending_count': pending.length,
      'oldest_pending_age_seconds': oldest < 0 ? 0 : oldest,
      'quarantined_count': rows.where((row) => row.quarantined).length,
      'dropped_overflow_count': dropped,
      'native_pending_files': nativeFiles.length,
      'native_dropped_overflow_count': await _bridge.nativeDroppedOverflow(),
      'last_success_at': lastSuccess == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              lastSuccess,
              isUtc: true,
            ).toIso8601String(),
    });
    await _preferences.setString(_healthDayKey, today);
  }

  Future<int> _nextSequence() async {
    final current = _preferences.getInt(_sequenceKey) ?? 0;
    final next = current + 1;
    await _preferences.setInt(_sequenceKey, next);
    return next;
  }

  Future<void> setCurrentUser(String? userId) async {
    currentUserId = userId;
    await _bridge.setOwnerUserId(userId);
    if (userId != null) {
      await _uploadConsent();
    }
  }

  Future<void> _rememberConsentUpload({
    required bool consented,
    required String surface,
  }) async {
    final row = {
      'consent_id': _uuid.v4(),
      'install_id': await ensureInstallId(),
      'consented': consented,
      'policy_version': analyticsPolicyVersion,
      'decided_at': _clock().toUtc().toIso8601String(),
      'surface': surface,
    };
    await _preferences.setString(_consentUploadKey, jsonEncode(row));
    await _uploadConsent();
  }

  Future<void> _uploadConsent() async {
    final raw = _preferences.getString(_consentUploadKey);
    final userId = currentUserId;
    final upload = onConsentRow;
    if (raw == null || userId == null || upload == null) {
      return;
    }
    final row = Map<String, Object?>.from(jsonDecode(raw) as Map);
    row['user_id'] = userId;
    try {
      await upload(row);
      await _preferences.remove(_consentUploadKey);
    } catch (error, stackTrace) {
      debugPrint('[AYG] analytics consent upload failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _clearNativePending() async {
    final files = await _bridge.drainPending();
    if (files.isEmpty) {
      return;
    }
    await _bridge.ackPending(files.map((file) => file.name).toList());
  }

  Future<void> _waitInFlight() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(List<Future<void>>.from(_inFlight));
    }
  }

  Map<String, Object?> _sanitize(String name, Map<String, Object?> props) {
    final allowed = AnalyticsEventNames.allowedProps[name] ?? const <String>{};
    final clean = <String, Object?>{};
    final unexpected = <String>[];
    for (final entry in props.entries) {
      if (entry.value == null) {
        continue;
      }
      if (allowed.contains(entry.key)) {
        clean[entry.key] = entry.value;
        continue;
      }
      assert(() {
        throw AssertionError('unexpected prop ${entry.key} on $name');
      }());
      unexpected.add(entry.key);
    }
    if (unexpected.isNotEmpty) {
      clean['_unexpected_keys'] = unexpected;
    }
    return clean;
  }
}

class FlushReport {
  const FlushReport({required this.sent});

  final int sent;
}
