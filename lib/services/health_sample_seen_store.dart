import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../platform/ios_backup_exclusion.dart';

/// この端末で、Health の実データを1回でも受け取ったか。
///
/// SharedPreferences には置かない。端末バックアップは設定を戻しても
/// HealthKit の許可は戻さないので、バックアップ対象のフラグだと
/// 空の読み取りを「本物の 0」と誤る。iOS ではファイルをバックアップから外す。
abstract class HealthSampleSeenStore {
  Future<bool> hasSeen();

  Future<void> markSeen();
}

class FileHealthSampleSeenStore implements HealthSampleSeenStore {
  FileHealthSampleSeenStore({this.directory, this.excludeFromBackup});

  static const fileName = 'health_sample_seen';

  final Future<Directory> Function()? directory;

  /// テストが記録する。本番は iOS のバックアップ除外チャンネル。
  /// true のときだけ印を残す。
  final Future<bool> Function(String path)? excludeFromBackup;

  Future<File?> _file() async {
    try {
      final dir = directory != null
          ? await directory!()
          : await getApplicationSupportDirectory();
      return File('${dir.path}${Platform.pathSeparator}$fileName');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> hasSeen() async {
    final file = await _file();
    if (file == null) {
      return false;
    }
    try {
      return file.existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> markSeen() async {
    final file = await _file();
    if (file == null) {
      return;
    }
    try {
      if (!file.existsSync()) {
        await file.parent.create(recursive: true);
        await file.writeAsString('1', flush: true);
      }
      if (!await _excludedFromBackup(file.path)) {
        await _forget(file);
      }
    } catch (_) {
      await _forget(file);
    }
  }

  /// 除外できなかった印は残さない。バックアップで戻ると、空の読み取りが本物の 0 になる。
  Future<bool> _excludedFromBackup(String path) async {
    final exclude = excludeFromBackup;
    if (exclude != null) {
      return exclude(path);
    }
    if (kIsWeb || !Platform.isIOS) {
      return true;
    }
    final excluded = await iosBackupExclusionChannel.invokeMethod<bool>(
      'excludeFromBackup',
      {'path': path},
    );
    return excluded == true;
  }

  Future<void> _forget(File file) async {
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

/// 本番はバックアップ対象外のファイル。テストはメモリ（path_provider を待たない）。
HealthSampleSeenStore defaultHealthSampleSeenStore() {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    return MemoryHealthSampleSeenStore();
  }
  return FileHealthSampleSeenStore();
}

class MemoryHealthSampleSeenStore implements HealthSampleSeenStore {
  MemoryHealthSampleSeenStore({this.seen = false});

  bool seen;

  @override
  Future<bool> hasSeen() async => seen;

  @override
  Future<void> markSeen() async {
    seen = true;
  }
}
