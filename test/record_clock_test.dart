import 'package:ayg/models/alcohol_entry.dart';
import 'package:ayg/models/calculation/weight_sample.dart';
import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/models/health_snapshot.dart';
import 'package:ayg/models/health_profile_data.dart';
import 'package:ayg/models/weight_entry.dart';
import 'package:ayg/repositories/supabase/exercise_entry_row_mapper.dart';
import 'package:ayg/repositories/supabase/food_master_row_mapper.dart';
import 'package:ayg/services/exercise_weight_resolver.dart';
import 'package:ayg/services/recent_foods.dart';
import 'package:ayg/services/weight_for_target.dart';
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

  test(
    'a local value still on the device is sent as wall digits, not shifted',
    () {
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
        expect(
          sent.millisecondsSinceEpoch,
          isNot(local.toUtc().millisecondsSinceEpoch),
        );
      }
    },
  );

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

  test('mixed old and new rows keep time, content, and count', () {
    final legacy = DateTime.parse('2026-07-20T20:15:00.000Z');
    final fresh = stampRecordInstant(DateTime(2026, 10, 17, 15, 49));
    final original = [
      FoodEntry(
        id: 'old-row',
        name: 'トースト',
        kcalPerBase: 180,
        quantity: 1,
        memo: '朝',
        loggedAt: legacy,
      ),
      FoodEntry(
        id: 'new-row',
        name: '鶏むね',
        kcalPerBase: 100,
        baseAmount: 100,
        unitType: FoodUnitType.g,
        consumedAmount: 120,
        memo: '昼',
        loggedAt: fresh,
      ),
    ];

    List<FoodEntry> deviceLoad(List<FoodEntry> stored) {
      return [
        for (final entry in stored)
          FoodEntry(
            id: entry.id,
            name: entry.name,
            kcalPerBase: entry.kcalPerBase,
            baseAmount: entry.baseAmount,
            unitType: entry.unitType,
            consumedAmount: entry.consumedAmount,
            memo: entry.memo,
            loggedAt: entry.loggedAt,
          ),
      ];
    }

    String timestamptz(String iso) =>
        DateTime.parse(iso).toUtc().toIso8601String();

    List<Map<String, dynamic>> serverRows(List<FoodEntry> entries) {
      return [
        for (final entry in entries)
          FoodMasterRowMapper.foodEntryToRow(entry, userId: 'user-1'),
      ];
    }

    List<FoodEntry> fromServer(List<Map<String, dynamic>> rows) {
      return [
        for (final row in rows)
          FoodMasterRowMapper.foodEntryFromRow({
            ...row,
            'user_id': 'user-1',
            'logged_at': timestamptz(row['logged_at'] as String),
          }),
      ];
    }

    void expectSameRecords(List<FoodEntry> left, List<FoodEntry> right) {
      expect(right.length, left.length);
      for (var i = 0; i < left.length; i++) {
        expect(right[i].id, left[i].id);
        expect(right[i].name, left[i].name);
        expect(right[i].kcalPerBase, left[i].kcalPerBase);
        expect(right[i].consumedAmount, left[i].consumedAmount);
        expect(right[i].memo, left[i].memo);
        expect(right[i].loggedAt.toUtc(), left[i].loggedAt.toUtc());
        expect(civilClock(right[i].loggedAt), civilClock(left[i].loggedAt));
      }
    }

    final onDevice = deviceLoad(original);
    expectSameRecords(original, onDevice);

    final server = fromServer(serverRows(original));
    expectSameRecords(original, server);
    final serverAgain = fromServer(serverRows(server));
    expectSameRecords(original, serverAgain);

    final reinstalled = fromServer(serverRows(original));
    expectSameRecords(original, reinstalled);
    expect(reinstalled.map((entry) => entry.id).toList(), [
      'old-row',
      'new-row',
    ]);
  });

  test('Isar-local absolute instants encode back to true UTC', () {
    final wall = DateTime(2026, 10, 8, 23, 30, 12);
    final stamped = stampRecordInstant(wall);
    final stored = persistRecordInstant(stamped);
    final recalled = recallRecordInstant(stored.toLocal());

    expect(stored.isUtc, isFalse);
    expect(recalled, stamped);
    expect(encodeRecordInstant(stored), stamped);
    expect(civilClock(recalled).hour, wall.hour);
    expect(civilClock(recalled).minute, wall.minute);
  });

  test('legacy UTC stored for Isar keeps the wall digits', () {
    final legacy = DateTime.parse('2026-10-08T01:15:00.000Z');
    final stored = persistRecordInstant(legacy);
    final recalled = recallRecordInstant(stored);

    expect(stored.isUtc, isFalse);
    expect(stored.hour, 1);
    expect(stored.minute, 15);
    expect(recalled.hour, 1);
    expect(encodeRecordInstant(recalled).hour, 1);
    expect(encodeRecordInstant(recalled).isUtc, isTrue);
    expect(isAbsoluteRecordInstant(recalled), isFalse);
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

  test('mixed old and new rows keep civil order and the later weight', () {
    final legacyMorning = DateTime.utc(2026, 10, 17, 8);
    final freshLater = stampRecordInstant(DateTime(2026, 10, 17, 9));
    final ordered = [freshLater, legacyMorning]..sort(compareRecordInstants);

    expect(civilClock(ordered.first), civilClock(legacyMorning));
    expect(civilClock(ordered.last).hour, 9);

    final selection = selectWeight(
      samples: [
        WeightSample(
          kg: 80,
          measuredAt: legacyMorning,
          source: WeightSource.manual,
        ),
        WeightSample(
          kg: 70,
          measuredAt: freshLater,
          source: WeightSource.manual,
        ),
      ],
      reference: DateTime(2026, 10, 17, 12),
      fallbackKg: 60,
    );
    expect(selection.kg, 70);

    final now = DateTime(2026, 10, 17, 12);
    final inside = stampRecordInstant(DateTime(2026, 10, 15, 0, 30));
    final outside = DateTime.utc(2026, 10, 14, 20);
    expect(foodLoggedWithinRecentWindow(inside, now), isTrue);
    expect(foodLoggedWithinRecentWindow(outside, now), isFalse);

    final noonLegacy = DateTime.utc(2026, 10, 17, 12);
    final eveningFresh = stampRecordInstant(DateTime(2026, 10, 17, 18));
    final foods = recentFoods([
      FoodEntry(id: 'legacy', name: 'パン', loggedAt: noonLegacy),
      FoodEntry(id: 'fresh', name: 'パン', loggedAt: eveningFresh),
      FoodEntry(id: 'outside', name: '味噌汁', loggedAt: outside),
    ], now);
    expect(foods.map((item) => item.latest.id), ['fresh']);

    final exerciseAt = DateTime(2026, 10, 17, 11, 30);
    final exerciseLegacy = DateTime.utc(2026, 10, 17, 11);
    final exerciseFresh = stampRecordInstant(DateTime(2026, 10, 17, 10));
    final weight = const ExerciseWeightResolver().resolve(
      exerciseLoggedAt: exerciseAt,
      weightEntries: [
        WeightEntry(
          id: 'fresh',
          weightKg: 70,
          recordedAt: exerciseFresh,
          source: WeightSource.manual,
        ),
        WeightEntry(
          id: 'legacy',
          weightKg: 80,
          recordedAt: exerciseLegacy,
          source: WeightSource.manual,
        ),
      ],
    );
    expect(weight?.weightKg, 80);

    if (DateTime.now().timeZoneOffset == const Duration(hours: 9)) {
      expect(freshLater.isBefore(legacyMorning), isTrue);
      final rawDay = DateTime(inside.year, inside.month, inside.day);
      final rawStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 2));
      expect(rawDay.isBefore(rawStart), isTrue);
      expect(outside.toLocal().day, 15);
      expect(eveningFresh.isBefore(noonLegacy), isTrue);
      expect(exerciseLegacy.isAfter(exerciseAt), isTrue);
    }
  });
}
