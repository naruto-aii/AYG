import 'dart:convert';

/// 端末で作る 1 件。データベースの `app_events` と同じ項目。
class AnalyticsEvent {
  AnalyticsEvent({
    required this.eventId,
    required this.eventName,
    required this.occurredAt,
    required this.origin,
    required this.installId,
    required this.sessionId,
    required this.stream,
    required this.sequenceNumber,
    required this.appVersion,
    required this.appBuild,
    required this.osVersion,
    required this.deviceModel,
    required this.locale,
    required this.timeZone,
    required this.schemaVersion,
    required this.props,
    this.userId,
  });

  final String eventId;
  final String eventName;
  final DateTime occurredAt;
  final String origin;
  final String installId;
  final String? sessionId;
  final String stream;
  final int sequenceNumber;
  final String appVersion;
  final String appBuild;
  final String? osVersion;
  final String? deviceModel;
  final String? locale;
  final String? timeZone;
  final int schemaVersion;
  final Map<String, Object?> props;
  String? userId;

  Map<String, Object?> toJson() {
    return {
      'event_id': eventId,
      'event_name': eventName,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'origin': origin,
      'install_id': installId,
      'session_id': sessionId,
      'stream': stream,
      'sequence_number': sequenceNumber,
      'app_version': appVersion,
      'app_build': appBuild,
      'os_version': osVersion,
      'device_model': deviceModel,
      'locale': locale,
      'time_zone': timeZone,
      'schema_version': schemaVersion,
      'props': props,
      'user_id': userId,
    };
  }

  /// サーバーへ upsert する行。`user_id` が無い間は送らない。
  Map<String, dynamic> toRow({required DateTime clientSentAt}) {
    return {
      'event_id': eventId,
      'user_id': userId,
      'event_name': eventName,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'client_sent_at': clientSentAt.toUtc().toIso8601String(),
      'origin': origin,
      'install_id': installId,
      'session_id': sessionId,
      'stream': stream,
      'sequence_number': sequenceNumber,
      'app_version': _clip(appVersion, 32),
      'app_build': _clip(appBuild, 32),
      'os_version': _clipOrNull(osVersion, 32),
      'device_model': _clipOrNull(deviceModel, 64),
      'locale': _clipOrNull(locale, 35),
      'time_zone': _clipOrNull(timeZone, 64),
      'schema_version': schemaVersion,
      'props': props,
      'advertising_use': false,
    };
  }

  static AnalyticsEvent fromJson(Map<String, Object?> json) {
    final propsRaw = json['props'];
    return AnalyticsEvent(
      eventId: json['event_id']! as String,
      eventName: json['event_name']! as String,
      occurredAt: DateTime.parse(json['occurred_at']! as String),
      origin: json['origin']! as String,
      installId: json['install_id']! as String,
      sessionId: json['session_id'] as String?,
      stream: json['stream']! as String,
      sequenceNumber: (json['sequence_number'] as num).toInt(),
      appVersion: json['app_version'] as String? ?? '',
      appBuild: json['app_build'] as String? ?? '',
      osVersion: json['os_version'] as String?,
      deviceModel: json['device_model'] as String?,
      locale: json['locale'] as String?,
      timeZone: json['time_zone'] as String?,
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      props: propsRaw is Map
          ? Map<String, Object?>.from(propsRaw)
          : <String, Object?>{},
      userId: (json['user_id'] ?? json['owner_user_id']) as String?,
    );
  }

  String encode() => jsonEncode(toJson());

  static AnalyticsEvent decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('analytics event is not an object');
    }
    return fromJson(Map<String, Object?>.from(decoded));
  }

  int get propsOctets => utf8.encode(jsonEncode(props)).length;
}

String _clip(String value, int max) {
  if (value.length <= max) {
    return value;
  }
  return value.substring(0, max);
}

String? _clipOrNull(String? value, int max) {
  if (value == null || value.isEmpty) {
    return null;
  }
  return _clip(value, max);
}
