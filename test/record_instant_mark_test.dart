import 'dart:convert';
import 'dart:io';

import 'package:ayg/database/schemas.dart';
import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/repositories/isar/food_repository.dart';
import 'package:ayg/repositories/supabase/exercise_entry_row_mapper.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/services/lock_screen_meal.dart';
import 'package:ayg/utils/local_date.dart';
import 'package:ayg/utils/record_clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'helpers/fake_postgrest.dart';

/// 0:00〜8:59（日本時間）の新しい記録は、印（ミリ秒 0・マイクロ秒 1）が
/// 落ちると前日の UTC の数字を壁時計として読んでしまう。
void main() {
  Directory? dir;
  Isar? isar;

  setUp(() async {
    expect(
      DateTime(2026, 10, 17).timeZoneOffset,
      const Duration(hours: 9),
      reason: 'このテストは TZ=Asia/Tokyo で動かす',
    );
    final openedDir = await Directory.systemTemp.createTemp('record_instant_mark');
    dir = openedDir;
    isar = await Isar.open(
      [FoodEntryEntitySchema],
      directory: openedDir.path,
      name: 'mark_${DateTime.now().microsecondsSinceEpoch}',
    );
  });

  tearDown(() async {
    final opened = isar;
    if (opened != null && opened.isOpen) {
      await opened.close(deleteFromDisk: true);
    }
    final openedDir = dir;
    if (openedDir != null && openedDir.existsSync()) {
      await openedDir.delete(recursive: true);
    }
  });

  const dayLabel = '2026年10月17日（土）';
  const previousLabel = '2026年10月16日（金）';

  final walls = <String, DateTime>{
    '0:00': DateTime(2026, 10, 17, 0, 0),
    '8:59': DateTime(2026, 10, 17, 8, 59),
    '9:00': DateTime(2026, 10, 17, 9, 0),
    '23:59': DateTime(2026, 10, 17, 23, 59),
  };

  test('the mark survives Isar, JSON, timestamptz, reinstall, and display', () async {
    final repo = FoodRepository(isar!);
    final freshDir = await Directory.systemTemp.createTemp('record_instant_reinstall');
    final fresh = await Isar.open(
      [FoodEntryEntitySchema],
      directory: freshDir.path,
      name: 'reinstall_${DateTime.now().microsecondsSinceEpoch}',
    );
    addTearDown(() async {
      await fresh.close(deleteFromDisk: true);
      await freshDir.delete(recursive: true);
    });
    final reinstall = FoodRepository(fresh);

    for (final entry in walls.entries) {
      final label = entry.key;
      final wall = entry.value;
      final stamped = stampRecordInstant(wall);
      expect(isAbsoluteRecordInstant(stamped), isTrue, reason: label);

      final food = FoodEntry(
        id: 'food-$label',
        name: label,
        kcalPerBase: 100,
        loggedAt: stamped,
      );
      await repo.save(food);
      final onDevice = (await repo.loadAll()).singleWhere((row) => row.id == food.id);
      expect(isAbsoluteRecordInstant(onDevice.loggedAt), isTrue, reason: label);
      expectWall(onDevice.loggedAt, wall, 'Isar $label');

      final row = FoodMasterRowMapper.foodEntryToRow(onDevice, userId: 'user');
      final sent = row['logged_at'] as String;
      expect(sent, contains('.000001'), reason: 'json source $label');
      final payload = jsonDecode(jsonEncode(row)) as Map<String, dynamic>;
      expect(payload['logged_at'], sent, reason: 'json $label');

      final stored = FakePostgrest.timestamptz(payload['logged_at'] as String);
      expect(stored, contains('000001'), reason: 'timestamptz $label');
      expect(stored, endsWith('+00:00'), reason: label);

      final restored = FoodMasterRowMapper.foodEntryFromRow({
        ...payload,
        'logged_at': stored,
      });
      expect(isAbsoluteRecordInstant(restored.loggedAt), isTrue, reason: label);
      expectWall(restored.loggedAt, wall, 'select $label');

      await reinstall.save(restored);
      final shown = (await reinstall.loadAll()).singleWhere((row) => row.id == food.id);
      expect(isAbsoluteRecordInstant(shown.loggedAt), isTrue, reason: label);
      expect(formatRecordDate(shown.loggedAt), dayLabel, reason: label);
      expect(formatRecordMinute(shown.loggedAt), '${wall.hour}:${wall.minute.toString().padLeft(2, '0')}', reason: label);
      expect(
        isLoggedOnLocalDay(shown.loggedAt, DateTime(2026, 10, 17, 12)),
        isTrue,
        reason: label,
      );
      expect(
        isLoggedOnLocalDay(shown.loggedAt, DateTime(2026, 10, 16, 12)),
        isFalse,
        reason: label,
      );

      final exercise = ExerciseEntryRowMapper.fromRow(
        ExerciseEntryRowMapper.toRow(
          ExerciseEntry(
            id: 'ex-$label',
            name: label,
            durationMin: 10,
            burnedKcal: 40,
            loggedAt: stamped,
          ),
          userId: 'user',
        )..['logged_at'] = stored,
      );
      expectWall(exercise.loggedAt, wall, 'exercise $label');

      final alcoholRow = FoodMasterRowMapper.alcoholEntryToRow(
        AlcoholEntry(
          id: 'alc-$label',
          beverageName: label,
          amount: 100,
          unit: 'ml',
          alcoholPercentage: 5,
          totalCalories: 40,
          pureAlcoholGrams: 4,
          alcoholCalories: 28,
          consumedAt: stamped,
        ),
        userId: 'user',
      );
      alcoholRow['consumed_at'] = stored;
      final alcohol = FoodMasterRowMapper.alcoholEntryFromRow(alcoholRow);
      expectWall(alcohol.consumedAt, wall, 'alcohol $label');

      final weightWire = FakePostgrest.timestamptz(encodeRecordTimestamp(stamped));
      expectWall(DateTime.parse(weightWire), wall, 'weight $label');
    }
  });

  test('widget and Siri keep 0:00 through 23:59 on the same JST day', () {
    for (final entry in walls.entries) {
      final wall = entry.value;
      final stamped = stampRecordInstant(wall);
      final appGroup = formatLockScreenLoggedAt(stamped);
      expect(appGroup, contains('.000001'), reason: entry.key);
      expect(appGroup, isNot(contains('Z')));
      expect(appGroup, isNot(contains('+')));
      final fromWidget = parseLockScreenLoggedAt(appGroup);
      expectWall(fromWidget, wall, 'widget ${entry.key}');

      // Swift の formatLoggedAt はミリ秒までで、印は付かない。壁時計の数字なので日はずれない。
      final swift = '${_iso(wall)}.000';
      final fromSiri = _loggedAtForTest(swift);
      expect(fromSiri, isNotNull, reason: entry.key);
      expect(isAbsoluteRecordInstant(fromSiri!), isTrue, reason: entry.key);
      expectWall(fromSiri, wall, 'siri ${entry.key}');
      expect(formatRecordDate(fromSiri), dayLabel, reason: entry.key);
    }
  });

  test('a marked UTC string is not read as wall digits', () {
    final morning = stampRecordInstant(DateTime(2026, 10, 17, 0, 30));
    final wire = encodeRecordTimestamp(morning);
    final parsed = parseLockScreenLoggedAt(wire);
    expect(isAbsoluteRecordInstant(parsed), isTrue);
    expect(formatRecordDate(parsed), dayLabel);
    expect(formatRecordMinute(parsed), '0:30');
  });

  test('dropping the mark from a true UTC morning moves it to the previous day', () {
    final midnight = stampRecordInstant(walls['0:00']!);
    final edge = stampRecordInstant(walls['8:59']!);
    final strippedMidnight = encodeRecordTimestamp(midnight).replaceFirst('.000001', '');
    final strippedEdge = encodeRecordTimestamp(edge).replaceFirst('.000001', '');
    expect(formatRecordDate(DateTime.parse(strippedMidnight)), previousLabel);
    expect(formatRecordDate(DateTime.parse(strippedEdge)), previousLabel);
    expect(formatRecordMinute(DateTime.parse(strippedMidnight)), '15:00');
    expect(formatRecordMinute(DateTime.parse(strippedEdge)), '23:59');

    // 9:00 と 23:59 は UTC の日付が同じなので、印が落ちても日は残る。時刻は9時間ずれる。
    final nine = stampRecordInstant(walls['9:00']!);
    final late = stampRecordInstant(walls['23:59']!);
    expect(
      formatRecordDate(DateTime.parse(encodeRecordTimestamp(nine).replaceFirst('.000001', ''))),
      dayLabel,
    );
    expect(
      formatRecordMinute(DateTime.parse(encodeRecordTimestamp(late).replaceFirst('.000001', ''))),
      '14:59',
    );
  });

  test('legacy wall-as-UTC morning stays on that wall day', () {
    final legacy = DateTime.parse('2026-10-17T00:00:00+00:00');
    expect(isAbsoluteRecordInstant(legacy), isFalse);
    expect(formatRecordDate(legacy), dayLabel);
    expect(formatRecordMinute(legacy), '0:00');
    expect(civilClock(legacy).hour, 0);
  });
}

void expectWall(DateTime value, DateTime wall, String reason) {
  final clock = civilClock(value);
  expect(
    [
      clock.year,
      clock.month,
      clock.day,
      clock.hour,
      clock.minute,
      clock.second,
    ],
    [wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second],
    reason: reason,
  );
}

String _iso(DateTime wall) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${wall.year.toString().padLeft(4, '0')}-${two(wall.month)}-${two(wall.day)}'
      'T${two(wall.hour)}:${two(wall.minute)}:${two(wall.second)}';
}

/// Siri の取り込みと同じ。`_loggedAt` はライブラリ内なので、公開されている入口で再現する。
DateTime? _loggedAtForTest(String text) {
  try {
    return asNewRecordInstant(parseLockScreenLoggedAt(text));
  } on FormatException {
    return null;
  }
}
