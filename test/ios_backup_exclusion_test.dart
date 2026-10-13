import 'dart:io';

import 'package:ayg/platform/ios_backup_exclusion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the HealthKit Isar files are marked for backup exclusion', () {
    final dir = Directory.systemTemp.createTempSync('ayg-backup');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/ayg.isar').writeAsStringSync('health');
    File('${dir.path}/ayg.isar-lck').writeAsStringSync('lock');
    File('${dir.path}/notes.txt').writeAsStringSync('other');

    final paths = healthBackupExclusionPaths(dir.path);

    expect(paths, contains('${dir.path}/ayg.isar'));
    expect(paths, contains('${dir.path}/ayg.isar-lck'));
    expect(paths, isNot(contains('${dir.path}/notes.txt')));
    expect(
      File('ios/Runner/AppDelegate.swift').readAsStringSync(),
      contains('isExcludedFromBackup = true'),
    );
    expect(
      File('lib/database/isar_service.dart').readAsStringSync(),
      contains('excludeHealthDatabaseFromBackup(dir)'),
    );
  });
}
