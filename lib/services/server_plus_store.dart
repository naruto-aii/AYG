import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// サーバが確認した、このアカウントの加入。ユーザーIDごとに端末へ残す。
class ServerPlusSnapshot {
  const ServerPlusSnapshot({
    required this.plus,
    required this.blocked,
    this.expiresAt,
  });

  final bool plus;
  final bool blocked;
  final DateTime? expiresAt;

  /// 別アカウントの購入ではなく、確認した期限が今よりあと。
  bool opensAt(DateTime now) =>
      !blocked && plus && expiresAt != null && expiresAt!.isAfter(now);
}

/// 起動のたびに加入を消さない。別のユーザーの結果は読まない。
class ServerPlusStore {
  ServerPlusStore({this._preferences}) : _memory = null;

  /// テスト用。端末の保存域には書かない。
  ServerPlusStore.memory() : _preferences = null, _memory = {};

  static const storageKey = 'server_plus_by_user_v1';

  final SharedPreferences? _preferences;
  final Map<String, ServerPlusSnapshot>? _memory;

  Future<ServerPlusSnapshot?> read(String userId) async {
    final id = _id(userId);
    if (id == null) {
      return null;
    }
    final memory = _memory;
    if (memory != null) {
      return memory[id];
    }
    final preferences = await _prefs();
    final row = _decode(preferences.getString(storageKey))[id];
    if (row is! Map) {
      return null;
    }
    final plus = row['plus'];
    if (plus is! bool) {
      return null;
    }
    final expiresAt = row['expiresAt'];
    return ServerPlusSnapshot(
      plus: plus,
      blocked: row['blocked'] == true,
      expiresAt: expiresAt is String ? DateTime.tryParse(expiresAt) : null,
    );
  }

  Future<void> write(String userId, ServerPlusSnapshot snapshot) async {
    final id = _id(userId);
    if (id == null) {
      return;
    }
    final memory = _memory;
    if (memory != null) {
      memory[id] = snapshot;
      return;
    }
    final preferences = await _prefs();
    final all = _decode(preferences.getString(storageKey));
    all[id] = {
      'plus': snapshot.plus,
      'blocked': snapshot.blocked,
      if (snapshot.expiresAt != null)
        'expiresAt': snapshot.expiresAt!.toUtc().toIso8601String(),
    };
    await preferences.setString(storageKey, jsonEncode(all));
  }

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? await SharedPreferences.getInstance();
  }

  static String? _id(String userId) {
    final id = userId.trim().toLowerCase();
    if (id.isEmpty) {
      return null;
    }
    return id;
  }

  static Map<String, dynamic> _decode(String? raw) {
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }
}
