import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_sync_repository.dart';

/// 検索・画面操作・コーチ・有料案内の未送信。アプリを落としても残す。
class PersistentEventOutbox {
  PersistentEventOutbox({this.preferences, required this.key});

  final SharedPreferences? preferences;
  final String key;
  Future<void> _tail = Future<void>.value();

  Future<T> _serialized<T>(Future<T> Function() action) {
    final done = _tail.then((_) => action());
    _tail = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<List<Map<String, dynamic>>> read() {
    return _serialized(() async {
      final store = preferences ?? await SharedPreferences.getInstance();
      final raw = store.getString(key);
      if (raw == null || raw.isEmpty) {
        return <Map<String, dynamic>>[];
      }
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        return <Map<String, dynamic>>[];
      }
      return [
        for (final item in decoded)
          if (item is Map) Map<String, dynamic>.from(item),
      ];
    });
  }

  Future<void> replace(List<Map<String, dynamic>> rows) {
    return _serialized(() async {
      final store = preferences ?? await SharedPreferences.getInstance();
      if (rows.isEmpty) {
        await store.remove(key);
        return;
      }
      await store.setString(key, jsonEncode(rows));
    });
  }

  Future<void> append(Map<String, dynamic> row) {
    return _serialized(() async {
      final store = preferences ?? await SharedPreferences.getInstance();
      final raw = store.getString(key);
      final rows = <Map<String, dynamic>>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            if (item is Map) {
              rows.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
      final id = row['id'];
      if (id != null) {
        rows.removeWhere((item) => item['id'] == id);
      }
      final kind = row['kind'];
      final source = row['source'];
      if (kind == 'food_search' || kind == 'exercise_search') {
        rows.removeWhere(
          (item) => item['kind'] == kind && item['source'] == source,
        );
      }
      rows.add(row);
      await store.setString(key, jsonEncode(rows));
    });
  }
}

/// 送れた、または一意制約で既にあるとき true。失敗はキューに残す。
Future<bool> deliverPersistentRow({
  required String table,
  required Map<String, dynamic> payload,
  required Set<String> requiredColumns,
  required Future<void> Function(Map<String, dynamic> row) send,
}) async {
  try {
    await upsertDroppingUnknownColumns(
      table: table,
      rows: [Map<String, dynamic>.from(payload)],
      requiredColumns: requiredColumns,
      upsert: (rows) => send(rows.single),
    );
    return true;
  } on PostgrestException catch (error) {
    if (error.code == '23505') {
      return true;
    }
    return false;
  } catch (_) {
    return false;
  }
}

/// 別ユーザーの行は残す。所有者不明の行だけ、今のユーザーにする。
bool outboxRowBelongsToOtherUser(Map<String, dynamic> row, String userId) {
  final owner = row['user_id'];
  return owner is String &&
      owner.isNotEmpty &&
      owner.toLowerCase() != userId.toLowerCase();
}

Map<String, dynamic> outboxPayloadForUser(
  Map<String, dynamic> row,
  String userId,
) {
  final raw = row['payload'];
  final payload = raw is Map
      ? Map<String, dynamic>.from(raw)
      : Map<String, dynamic>.from(row);
  final owner = payload['user_id'];
  if (owner == null || (owner is String && owner.isEmpty)) {
    payload['user_id'] = userId;
  }
  return payload;
}
