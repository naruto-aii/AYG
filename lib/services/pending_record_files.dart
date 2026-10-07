import 'dart:convert';
import 'dart:io';

/// ウィジェットと Siri の未取り込み記録。1件1ファイル。
/// 取り込み済みの id だけ消し、その後に追記されたファイルは残す。
class PendingRecordDirectory {
  PendingRecordDirectory(
    this.directory, {
    required this.idKey,
    this.legacyFileName = 'pending.json',
  });

  final Directory directory;
  final String idKey;
  final String legacyFileName;

  void append(Map<String, Object?> record) {
    directory.createSync(recursive: true);
    migrateLegacyFile();
    final id = _idOf(record);
    if (id == null) {
      return;
    }
    final file = _file(id);
    if (file.existsSync()) {
      return;
    }
    file.writeAsStringSync(jsonEncode(record), flush: true);
  }

  /// UserDefaults に残っていた配列を、同じ id のファイルが無いときだけ移す。
  void migrateLegacyArray(String? raw) {
    directory.createSync(recursive: true);
    _writeLegacyArray(raw);
  }

  List<Map<String, Object?>> readAll() {
    if (!directory.existsSync()) {
      return const [];
    }
    migrateLegacyFile();
    final files = directory.listSync().whereType<File>().where((file) {
      final name = file.uri.pathSegments.last;
      return name.endsWith('.json') &&
          name != legacyFileName &&
          !name.startsWith('.');
    }).toList();
    files.sort(
      (a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
    );
    final rows = <Map<String, Object?>>[];
    for (final file in files) {
      try {
        final decoded = jsonDecode(file.readAsStringSync());
        if (decoded is Map) {
          rows.add(Map<String, Object?>.from(decoded));
        }
      } catch (_) {
        continue;
      }
    }
    return rows;
  }

  String readJSON() => jsonEncode(readAll());

  void acknowledge(Iterable<String> ids) {
    if (!directory.existsSync()) {
      return;
    }
    migrateLegacyFile();
    for (final id in ids) {
      final file = _file(id);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
  }

  void migrateLegacyFile() {
    final legacy = File('${directory.path}/$legacyFileName');
    if (!legacy.existsSync()) {
      return;
    }
    final raw = legacy.readAsStringSync();
    legacy.deleteSync();
    _writeLegacyArray(raw);
  }

  void _writeLegacyArray(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return;
    }
    for (final item in decoded) {
      if (item is! Map) {
        continue;
      }
      append(Map<String, Object?>.from(item));
    }
  }

  String? _idOf(Map<String, Object?> record) {
    final id = record[idKey];
    if (id is! String || id.trim().isEmpty) {
      return null;
    }
    return id.trim();
  }

  File _file(String id) {
    final safe = id.replaceAll('/', '_');
    return File('${directory.path}/$safe.json');
  }
}
