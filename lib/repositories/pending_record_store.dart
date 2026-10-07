import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 食事・運動・飲酒・体重の、まだ本番へ届いていない変更。
enum PendingRecordKind { food, exercise, alcohol, weight }

/// 未送信の上書きと削除。取り込みは、この印が付いた行を手元優先にする。
class PendingRecordStore {
  PendingRecordStore({this._preferences});

  static const storageKey = 'pending_record_flags_v1';

  final SharedPreferences? _preferences;
  final Set<String> _upserts = {};
  final Set<String> _deletes = {};
  final Set<String> _tables = {};
  bool _loaded = false;

  Future<void> _ensure() async {
    if (_loaded) {
      return;
    }
    _loaded = true;
    final raw = _preferences?.getString(storageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return;
    }
    _upserts.addAll(_strings(decoded['upserts']));
    _deletes.addAll(_strings(decoded['deletes']));
    _tables.addAll(_strings(decoded['tables']));
  }

  Iterable<String> _strings(Object? raw) {
    if (raw is! List) {
      return const [];
    }
    return [for (final item in raw) if (item is String) item];
  }

  String _token(PendingRecordKind kind, String id) => '${kind.name}:$id';

  Future<void> markUpsert(PendingRecordKind kind, String id) async {
    await _ensure();
    final token = _token(kind, id);
    _deletes.remove(token);
    _upserts.add(token);
    await _persist();
  }

  Future<void> markDelete(PendingRecordKind kind, String id) async {
    await _ensure();
    final token = _token(kind, id);
    _upserts.remove(token);
    _deletes.add(token);
    await _persist();
  }

  /// 送信できた行の未送信印を外す。
  Future<void> acknowledgeUpserts(
    PendingRecordKind kind,
    Iterable<String> ids,
  ) async {
    await _ensure();
    for (final id in ids) {
      _upserts.remove(_token(kind, id));
    }
    await _persist();
  }

  /// 削除が本番で確認できた行の印を外す。
  Future<void> forget(PendingRecordKind kind, String id) async {
    await _ensure();
    final token = _token(kind, id);
    _upserts.remove(token);
    _deletes.remove(token);
    await _persist();
  }

  Future<Set<String>> preferLocalIds(PendingRecordKind kind) async {
    await _ensure();
    return _ids(kind, _upserts);
  }

  Future<Set<String>> pendingDeleteIds(PendingRecordKind kind) async {
    await _ensure();
    return _ids(kind, _deletes);
  }

  Set<String> _ids(PendingRecordKind kind, Set<String> tokens) {
    final prefix = '${kind.name}:';
    return {
      for (final token in tokens)
        if (token.startsWith(prefix)) token.substring(prefix.length),
    };
  }

  /// 送信に失敗した表。取り込みで上書きしない。
  Future<void> markTableDirty(String table) async {
    await _ensure();
    _tables.add(table);
    await _persist();
  }

  Future<void> acknowledgeTable(String table) async {
    await _ensure();
    _tables.remove(table);
    await _persist();
  }

  Future<bool> isTableDirty(String table) async {
    await _ensure();
    return _tables.contains(table);
  }

  Future<Set<String>> dirtyTables() async {
    await _ensure();
    return Set<String>.from(_tables);
  }

  Future<int> count() async {
    await _ensure();
    return _upserts.length + _deletes.length + _tables.length;
  }

  Future<void> clear() async {
    await _ensure();
    _upserts.clear();
    _deletes.clear();
    _tables.clear();
    await _persist();
  }

  Future<void> _persist() async {
    final preferences = _preferences;
    if (preferences == null) {
      return;
    }
    await preferences.setString(
      storageKey,
      jsonEncode({
        'upserts': _upserts.toList()..sort(),
        'deletes': _deletes.toList()..sort(),
        'tables': _tables.toList()..sort(),
      }),
    );
  }
}
