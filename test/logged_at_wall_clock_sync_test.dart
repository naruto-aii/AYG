import 'dart:io';

import 'package:ayg/database/schemas.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/isar/exercise_repository.dart';
import 'package:ayg/repositories/isar/food_repository.dart';
import 'package:ayg/repositories/isar/weight_repository.dart';
import 'package:ayg/repositories/supabase/exercise_entry_row_mapper.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/utils/local_date.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

/// Postgres の timestamptz と同じく、オフセット無しの文字列は UTC として受け取り、
/// PostgREST と同じ `+00:00` 付きで返す。
String _storeAsTimestamptz(String sent) {
  final hasOffset = RegExp(r'(Z|[+-]\d\d:?\d\d)$').hasMatch(sent);
  final utc = DateTime.parse(hasOffset ? sent : '${sent}Z').toUtc();
  final text = utc.toIso8601String();
  return '${text.substring(0, 19)}+00:00';
}

void main() {
  late Directory dir;
  late Isar isar;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wall_clock_sync');
    isar = await Isar.open(
      [FoodEntryEntitySchema, ExerciseEntryEntitySchema, WeightEntryEntitySchema],
      directory: dir.path,
      name: 'wall_clock_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
    await dir.delete(recursive: true);
  });

  test('DB の壁時計は端末の壁時計として読み、同じ文字列で送り返す', () {
    final parsed = wallClockFromDb('2026-10-08T01:17:18+00:00');
    expect(parsed.isUtc, isFalse);
    expect(
      [parsed.year, parsed.month, parsed.day, parsed.hour, parsed.minute],
      [2026, 10, 8, 1, 17],
    );
    expect(wallClockToDb(parsed), '2026-10-08T01:17:18.000');
    // 端末 DB（Isar）は UTC で保存し toLocal() で返す。その往復でも変わらない。
    final viaIsar = DateTime.fromMicrosecondsSinceEpoch(
      parsed.toUtc().microsecondsSinceEpoch,
      isUtc: true,
    ).toLocal();
    expect(wallClockToDb(viaIsar), '2026-10-08T01:17:18.000');
    // 古い経路の UTC 値も、年月日時刻をそのまま壁時計として送る。
    expect(wallClockToDb(DateTime.utc(2026, 10, 8, 1, 17, 18)),
        '2026-10-08T01:17:18.000');
  });

  test('再インストール後の復元と同期を何度繰り返しても食事の日時がずれない', () async {
    final repo = FoodRepository(isar);
    var serverValue = '2026-10-08T01:17:18+00:00';
    for (var round = 0; round < 3; round++) {
      await repo.clearAll();
      final pulled = FoodMasterRowMapper.foodEntryFromRow({
        'entry_id': 'f1',
        'name': '朝ごはん',
        'kcal_per_unit': 300,
        'quantity': 1,
        'logged_at': serverValue,
      });
      await repo.saveAll([pulled]);
      final local = (await repo.loadAll()).single;
      expect([local.loggedAt.day, local.loggedAt.hour, local.loggedAt.minute],
          [8, 1, 17], reason: 'round $round');
      final row = FoodMasterRowMapper.foodEntryToRow(local, userId: 'u1');
      serverValue = _storeAsTimestamptz(row['logged_at'] as String);
      expect(serverValue, '2026-10-08T01:17:18+00:00', reason: 'round $round');
    }
  });

  test('端末で記録した食事は送信・取得・再送信で同じ日時のまま', () async {
    final repo = FoodRepository(isar);
    final entry = FoodEntry(
      id: 'f2',
      name: '豚の生姜焼き弁当',
      kcalPerBase: 650,
      loggedAt: DateTime(2026, 10, 8, 22, 13),
    );
    await repo.save(entry);
    final first = FoodMasterRowMapper.foodEntryToRow(
      (await repo.loadAll()).single,
      userId: 'u1',
    );
    final stored = _storeAsTimestamptz(first['logged_at'] as String);
    expect(stored, '2026-10-08T22:13:00+00:00');
    await repo.clearAll();
    await repo.saveAll([
      FoodMasterRowMapper.foodEntryFromRow({...first, 'logged_at': stored}),
    ]);
    final again = FoodMasterRowMapper.foodEntryToRow(
      (await repo.loadAll()).single,
      userId: 'u1',
    );
    expect(_storeAsTimestamptz(again['logged_at'] as String), stored);
    final shown = (await repo.loadAll()).single.loggedAt;
    expect(isLoggedOnLocalDay(shown, DateTime(2026, 10, 8)), isTrue);
    expect(isLoggedOnLocalDay(shown, DateTime(2026, 10, 9)), isFalse);
  });

  test('運動と体重も同期の往復で日時がずれない', () async {
    final exercises = ExerciseRepository(isar);
    final weights = WeightRepository(isar);
    var exerciseValue = '2026-10-08T08:20:40+00:00';
    var weightValue = '2026-10-08T07:05:00+00:00';
    for (var round = 0; round < 3; round++) {
      await exercises.clearAll();
      await exercises.saveAll([
        ExerciseEntryRowMapper.fromRow({
          'entry_id': 'x1',
          'name': 'ウォーキング',
          'duration_min': 30,
          'burned_kcal': 120,
          'logged_at': exerciseValue,
        }),
      ]);
      final exercise = (await exercises.loadAll()).single;
      exerciseValue = _storeAsTimestamptz(
        ExerciseEntryRowMapper.toRow(exercise, userId: 'u1')['logged_at']
            as String,
      );
      expect(exerciseValue, '2026-10-08T08:20:40+00:00', reason: 'round $round');

      await weights.clearAll();
      await weights.save(
        WeightEntry(
          id: 'w1',
          weightKg: 70,
          recordedAt: wallClockFromDb(weightValue),
          source: WeightSource.manual,
        ),
      );
      final weight = (await weights.loadAll()).single;
      weightValue = _storeAsTimestamptz(wallClockToDb(weight.recordedAt));
      expect(weightValue, '2026-10-08T07:05:00+00:00', reason: 'round $round');
    }
  });
}
