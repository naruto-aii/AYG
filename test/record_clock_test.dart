import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/supabase/exercise_entry_row_mapper.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/utils/local_date.dart';
import 'package:ayg/utils/record_clock.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy wall-as-UTC keeps the civil clock and the same instant', () {
    final legacy = DateTime.utc(2026, 7, 20, 20, 15);
    final civil = civilClock(legacy);

    expect(isAbsoluteRecordInstant(legacy), isFalse);
    expect(civil.isUtc, isFalse);
    expect(civil.year, 2026);
    expect(civil.month, 7);
    expect(civil.day, 20);
    expect(civil.hour, 20);
    expect(civil.minute, 15);
    expect(isLoggedOnLocalDay(legacy, DateTime(2026, 7, 20, 8)), isTrue);
    expect(isLoggedOnLocalDay(legacy, DateTime(2026, 7, 21)), isFalse);
    expect(encodeRecordInstant(legacy), legacy);
    expect(encodeRecordTimestamp(legacy), legacy.toUtc().toIso8601String());
  });

  test('a local value still on the device is sent as wall digits, not shifted', () {
    final local = DateTime(2026, 7, 20, 20, 15);
    final sent = encodeRecordInstant(local);

    expect(sent.isUtc, isTrue);
    expect(sent.year, local.year);
    expect(sent.month, local.month);
    expect(sent.day, local.day);
    expect(sent.hour, local.hour);
    expect(sent.minute, local.minute);
    expect(encodeRecordTimestamp(local), sent.toUtc().toIso8601String());
    if (local.timeZoneOffset != Duration.zero) {
      expect(sent.millisecondsSinceEpoch, isNot(local.toUtc().millisecondsSinceEpoch));
    }
  });

  test('new meals round-trip the civil minute, name, and count', () {
    final wall = DateTime(2026, 10, 17, 15, 49);
    final stamped = stampRecordInstant(wall);
    final entry = FoodEntry(
      id: 'meal-new',
      name: '鶏むね',
      kcalPerBase: 100,
      baseAmount: 100,
      unitType: FoodUnitType.g,
      consumedAmount: 100,
      loggedAt: stamped,
    );

    final row = FoodMasterRowMapper.foodEntryToRow(entry, userId: 'user-1');
    final loggedAt = row['logged_at'] as String;
    expect(loggedAt.endsWith('Z'), isTrue);
    expect(loggedAt.contains('.000001'), isTrue);

    final pulled = FoodMasterRowMapper.foodEntryFromRow({
      ...row,
      'user_id': 'user-1',
    });
    final again = FoodMasterRowMapper.foodEntryToRow(pulled, userId: 'user-1');

    expect(pulled.name, '鶏むね');
    expect([pulled].length, 1);
    expect(civilClock(pulled.loggedAt).year, 2026);
    expect(civilClock(pulled.loggedAt).month, 10);
    expect(civilClock(pulled.loggedAt).day, 17);
    expect(civilClock(pulled.loggedAt).hour, 15);
    expect(civilClock(pulled.loggedAt).minute, 49);
    expect(again['logged_at'], loggedAt);
    expect(again['name'], row['name']);
    expect(isLoggedOnLocalDay(pulled.loggedAt, wall), isTrue);
  });

  test('legacy food push does not change the stored instant', () {
    final legacy = DateTime.parse('2026-10-17T06:49:00.000Z');
    final entry = FoodEntry(
      id: 'meal-old',
      name: 'トースト',
      quantity: 1,
      loggedAt: legacy,
    );
    final row = FoodMasterRowMapper.foodEntryToRow(entry, userId: 'user-1');
    final pulled = FoodMasterRowMapper.foodEntryFromRow({
      ...row,
      'user_id': 'user-1',
    });

    expect(row['logged_at'], legacy.toUtc().toIso8601String());
    expect(pulled.loggedAt.toUtc(), legacy.toUtc());
    expect(civilClock(pulled.loggedAt).hour, 6);
    expect(civilClock(pulled.loggedAt).minute, 49);
    expect(pulled.name, 'トースト');
  });

  test('exercise, alcohol, weight, and health snapshot use the same clock', () {
    final wall = DateTime(2026, 10, 17, 8, 5);
    final stamped = stampRecordInstant(wall);

    final exercise = ExerciseEntryRowMapper.toRow(
      ExerciseEntry(
        id: 'ex-1',
        name: '歩く',
        durationMin: 20,
        burnedKcal: 80,
        loggedAt: stamped,
      ),
      userId: 'user-1',
    );
    final alcohol = FoodMasterRowMapper.alcoholEntryToRow(
      AlcoholEntry(
        id: 'al-1',
        beverageName: 'ビール',
        amount: 350,
        unit: 'ml',
        alcoholPercentage: 5,
        totalCalories: 140,
        pureAlcoholGrams: 14,
        alcoholCalories: 98,
        consumedAt: stamped,
      ),
      userId: 'user-1',
    );
    final weightAt = encodeRecordTimestamp(
      WeightEntry(
        id: 'w-1',
        weightKg: 70,
        recordedAt: stamped,
        source: WeightSource.manual,
      ).recordedAt,
    );
    final measured = encodeRecordTimestamp(
      HealthSnapshot(weightKg: 70, weightMeasuredAt: stamped).weightMeasuredAt!,
    );

    for (final raw in [
      exercise['logged_at'],
      alcohol['consumed_at'],
      weightAt,
      measured,
    ]) {
      final parsed = DateTime.parse(raw as String);
      expect(parsed.toUtc(), stamped.toUtc());
      expect(civilClock(parsed).hour, 8);
      expect(civilClock(parsed).minute, 5);
    }
  });

  test('confirming the same minute does not rewrite a legacy instant', () {
    final legacy = DateTime.utc(2026, 10, 17, 6, 49);
    final shown = civilClock(legacy);
    final kept = adoptPickedRecordTime(
      original: legacy,
      pickedLocal: DateTime(
        shown.year,
        shown.month,
        shown.day,
        shown.hour,
        shown.minute,
      ),
    );
    expect(kept, legacy);

    final changed = adoptPickedRecordTime(
      original: legacy,
      pickedLocal: DateTime(shown.year, shown.month, shown.day, 7, 10),
    );
    expect(isAbsoluteRecordInstant(changed), isTrue);
    expect(civilClock(changed).hour, 7);
    expect(civilClock(changed).minute, 10);
  });
}
