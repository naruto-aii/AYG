import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_service.dart';

/// 起動、前面、背面、セッション、版の変化、前回の異常終了。
class AnalyticsLifecycle {
  AnalyticsLifecycle({
    required AnalyticsService service,
    required SharedPreferences preferences,
    DateTime Function()? clock,
  }) : _service = service,
       _preferences = preferences,
       _clock = clock ?? DateTime.now;

  final AnalyticsService _service;
  final SharedPreferences _preferences;
  final DateTime Function() _clock;
  DateTime? _foregroundAt;
  var _screens = 0;
  var _openRecorded = false;

  static const _foregroundDirtyKey = 'analytics_foreground_dirty';
  static const _versionKey = 'analytics_last_app_version';
  static const _osKey = 'analytics_last_os_version';
  static const _sessionIdKey = 'analytics_session_id';
  static const _sessionNumberKey = 'analytics_session_number';
  static const _lastBackgroundKey = 'analytics_last_background_ms';
  static const _sessionStartKey = 'analytics_session_started_ms';
  static const _eventsInSessionKey = 'analytics_events_in_session';
  static const _screensInSessionKey = 'analytics_screens_in_session';
  static const _launchKey = 'analytics_has_launched';

  Future<void> onColdStart({String launchSource = 'icon'}) async {
    if (!_service.consented) {
      return;
    }
    final abnormal = _preferences.getBool(_foregroundDirtyKey) ?? false;
    final first = !(_preferences.getBool(_launchKey) ?? false);
    await _preferences.setBool(_launchKey, true);
    await _preferences.setBool(_foregroundDirtyKey, true);
    _foregroundAt = _clock();
    await _service.importNativePending();
    await _startSessionIfNeeded();
    await _noteWidgets();
    if (first) {
      final info = await _service.bridge.appTransactionInfo();
      await _service.track('app_install_first_open', {
        'original_purchase_date': info?['originalPurchaseDate'],
        'original_app_version': info?['originalAppVersion'],
        'app_transaction_environment': info?['environment'],
      });
    }
    await _service.track('app_open', {
      'launch_source': launchSource,
      'previous_session_abnormal_end': abnormal,
    });
    await _noteVersion();
    await _service.reportHealth(force: true);
    _openRecorded = true;
  }

  Future<void> onForeground() async {
    if (!_service.consented) {
      return;
    }
    final last = _preferences.getInt(_lastBackgroundKey);
    final now = _clock();
    final backgroundSeconds = last == null
        ? 0
        : now.difference(DateTime.fromMillisecondsSinceEpoch(last, isUtc: true)).inSeconds;
    await _preferences.setBool(_foregroundDirtyKey, true);
    _foregroundAt = now;
    _service.foreground = true;
    await _startSessionIfNeeded();
    await _service.track('app_foreground', {
      'background_seconds': backgroundSeconds < 0 ? 0 : backgroundSeconds,
    });
    await _service.importNativePending();
    await _service.flush();
  }

  Future<void> onBackground() async {
    if (!_service.consented) {
      return;
    }
    final now = _clock();
    final foregroundSeconds = _foregroundAt == null
        ? 0
        : now.difference(_foregroundAt!).inSeconds;
    await _service.track('app_background', {
      'foreground_seconds': foregroundSeconds < 0 ? 0 : foregroundSeconds,
      'current_screen': _service.currentScreen,
      'current_screen_dwell_ms': _dwellMs(now),
    });
    await _endSession(now);
    await _preferences.setBool(_foregroundDirtyKey, false);
    await _preferences.setInt(_lastBackgroundKey, now.toUtc().millisecondsSinceEpoch);
    _service.foreground = false;
    await _service.flush(budget: const Duration(seconds: 3));
  }

  void noteScreen() {
    _screens += 1;
    final current = _preferences.getInt(_screensInSessionKey) ?? 0;
    unawaited(_preferences.setInt(_screensInSessionKey, current + 1));
  }

  Future<void> _startSessionIfNeeded() async {
    final last = _preferences.getInt(_lastBackgroundKey);
    final existing = _preferences.getString(_sessionIdKey);
    final now = _clock();
    final gap = last == null
        ? null
        : now.difference(DateTime.fromMillisecondsSinceEpoch(last, isUtc: true));
    final fresh = existing == null || gap == null || gap >= const Duration(minutes: 30);
    if (!fresh) {
      return;
    }
    final number = (_preferences.getInt(_sessionNumberKey) ?? 0) + 1;
    await _preferences.setInt(_sessionNumberKey, number);
    await _preferences.setString(_sessionIdKey, analyticsSessionIdFromClock(now));
    await _preferences.setInt(_sessionStartKey, now.toUtc().millisecondsSinceEpoch);
    await _preferences.setInt(_eventsInSessionKey, 0);
    await _preferences.setInt(_screensInSessionKey, 0);
    _screens = 0;
    await _service.track('session_start', {
      'session_number': number,
      'gap_seconds': gap == null ? 0 : gap.inSeconds,
    });
  }

  Future<void> _endSession(DateTime now) async {
    final started = _preferences.getInt(_sessionStartKey);
    final duration = started == null
        ? 0
        : now.difference(DateTime.fromMillisecondsSinceEpoch(started, isUtc: true)).inSeconds;
    await _service.track('session_end', {
      'duration_seconds': duration < 0 ? 0 : duration,
      'screens_viewed': _preferences.getInt(_screensInSessionKey) ?? _screens,
      'events_count': _preferences.getInt(_eventsInSessionKey) ?? 0,
    });
  }

  Future<void> _noteWidgets() async {
    final counts = await _service.bridge.widgetConfigurations();
    await _service.track('widget_presence', {
      'home_widget_count': counts['home'] ?? counts['HomeMealWidget'] ?? 0,
      'lock_widget_count': counts['lock'] ?? counts['LockScreenMealWidget'] ?? 0,
    });
  }

  Future<void> _noteVersion() async {
    final previousApp = _preferences.getString(_versionKey);
    final previousOs = _preferences.getString(_osKey);
    final nextApp = _service.appVersion;
    final nextOs = _service.osVersion ?? '';
    if (previousApp != null && (previousApp != nextApp || (previousOs ?? '') != nextOs)) {
      await _service.track('app_version_changed', {
        'from_app_version': previousApp,
        'to_app_version': nextApp,
        'from_os_version': previousOs,
        'to_os_version': nextOs,
      });
    }
    await _preferences.setString(_versionKey, nextApp);
    await _preferences.setString(_osKey, nextOs);
  }

  int? _dwellMs(DateTime now) {
    final since = _service.currentScreenSince;
    if (since == null) {
      return null;
    }
    return now.difference(since).inMilliseconds;
  }

  bool get openRecorded => _openRecorded;
}

/// セッション ID は UUID。ライフサイクルが作る。
String analyticsSessionIdFromClock(DateTime clock) {
  final raw = clock.toUtc().microsecondsSinceEpoch.toRadixString(16).padLeft(32, '0');
  final body = raw.substring(raw.length - 32);
  return '${body.substring(0, 8)}-${body.substring(8, 12)}-4${body.substring(13, 16)}-a${body.substring(17, 20)}-${body.substring(20, 32)}';
}
