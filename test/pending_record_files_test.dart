import 'dart:io';

import 'package:ayg/services/pending_record_files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('one file per record survives a later acknowledge', () {
    final root = Directory.systemTemp.createTempSync('pending-records');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = PendingRecordDirectory(
      Directory('${root.path}/lock'),
      idKey: 'registrationId',
    );

    store.append({'registrationId': 'meal-a', 'name': '朝'});
    store.append({'registrationId': 'meal-b', 'name': '昼'});
    final seen = store.readAll().map((row) => row['registrationId']).toList();
    store.append({'registrationId': 'meal-c', 'name': '夜'});
    store.acknowledge(seen.cast<String>());

    final left = store.readAll();
    expect(left.map((row) => row['registrationId']), ['meal-c']);
    store.acknowledge(['meal-c']);
    expect(store.readAll(), isEmpty);
    store.acknowledge(['meal-c']);
    expect(store.readAll(), isEmpty);
  });

  test('the same id is not stored twice', () {
    final root = Directory.systemTemp.createTempSync('pending-once');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = PendingRecordDirectory(root, idKey: 'id');
    store.append({'id': 'same', 'name': 'first'});
    store.append({'id': 'same', 'name': 'second'});
    expect(store.readAll(), [
      {'id': 'same', 'name': 'first'},
    ]);
  });

  test('a legacy array file is migrated without dropping a new file', () {
    final root = Directory.systemTemp.createTempSync('pending-legacy');
    addTearDown(() => root.deleteSync(recursive: true));
    final store = PendingRecordDirectory(root, idKey: 'id');
    File('${root.path}/pending.json').writeAsStringSync(
      '[{"id":"old-1","kind":"food"},{"id":"old-2","kind":"food"}]',
    );
    store.append({'id': 'new-1', 'kind': 'food'});
    expect(
      store.readAll().map((row) => row['id']),
      containsAll(['old-1', 'old-2', 'new-1']),
    );
    expect(File('${root.path}/pending.json').existsSync(), isFalse);
    store.migrateLegacyArray('[{"id":"old-1","kind":"food"}]');
    expect(store.readAll().where((row) => row['id'] == 'old-1'), hasLength(1));
  });
}
