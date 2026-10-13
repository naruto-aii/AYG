import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const iosBackupExclusionChannel = MethodChannel(
  'com.narutoaii.ayg/backup_exclusion',
);

/// Isar の `ayg.isar` は、HealthKit から読んだ体格・消費カロリー・ワークアウトを持つ。
/// ファイル名が `ayg.isar` で始まるものだけを返す。
List<String> healthBackupExclusionPaths(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    return const [];
  }
  final paths = <String>[];
  for (final entity in dir.listSync(followLinks: false)) {
    final name = entity.path.split(Platform.pathSeparator).last;
    if (name.startsWith('ayg.isar')) {
      paths.add(entity.path);
    }
  }
  return paths;
}

/// iOS では、上のファイルに NSURLIsExcludedFromBackupKey を付ける。
Future<void> excludeHealthDatabaseFromBackup(String directory) async {
  if (kIsWeb || !Platform.isIOS) {
    return;
  }
  for (final path in healthBackupExclusionPaths(directory)) {
    try {
      await iosBackupExclusionChannel.invokeMethod<void>('excludeFromBackup', {
        'path': path,
      });
    } catch (error) {
      debugPrint('[AYG] exclude from backup failed: $error');
    }
  }
}
