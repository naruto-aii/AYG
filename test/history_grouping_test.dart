import 'package:flutter_test/flutter_test.dart';

import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/utils/history_grouping.dart';
import 'package:ayg/utils/local_date.dart';

void main() {
  final referenceDate = DateTime(2026, 7, 21, 12);

  group('sortFoodEntriesByLoggedAt', () {
    test('sorts by loggedAt ascending', () {
      final entries = [
        FoodEntry(
          id: '2',
          name: '昼',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 21, 12),
        ),
        FoodEntry(
          id: '1',
          name: '朝',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 21, 8),
        ),
      ];

      final sorted = sortFoodEntriesByLoggedAt(entries);

      expect(sorted.map((entry) => entry.id), ['1', '2']);
    });
  });

  group('groupFoodEntriesByDate', () {
    test('groups today entries only by default', () {
      final entries = [
        FoodEntry(
          id: '1',
          name: '今日',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 21, 8),
        ),
        FoodEntry(
          id: '2',
          name: '昨日',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 20, 8),
        ),
      ];

      final groups = groupFoodEntriesByDate(
        entries,
        referenceDate: referenceDate,
      );

      expect(groups, hasLength(1));
      expect(groups.first.label, '今日');
      expect(groups.first.items, hasLength(1));
      expect(groups.first.items.first.id, '1');
    });

    test('sorts items within each date group by loggedAt', () {
      final entries = [
        FoodEntry(
          id: '2',
          name: '後',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 21, 12),
        ),
        FoodEntry(
          id: '1',
          name: '先',
          quantity: 1,
          loggedAt: DateTime(2026, 7, 21, 8),
        ),
      ];

      final groups = groupFoodEntriesByDate(
        entries,
        referenceDate: referenceDate,
      );

      expect(groups.first.items.map((entry) => entry.id), ['1', '2']);
    });

    test('groups entries on local calendar day across UTC boundary', () {
      final loggedAt = DateTime.utc(2026, 7, 20, 15);
      final entries = [
        FoodEntry(
          id: '1',
          name: 'UTC evening local next day',
          quantity: 1,
          loggedAt: loggedAt,
        ),
      ];

      final localReference = localDayStart(loggedAt.toLocal());
      final groups = groupFoodEntriesByDate(
        entries,
        referenceDate: localReference,
        todayOnly: false,
      );

      expect(groups, hasLength(1));
      expect(groups.first.date, localReference);
      expect(groups.first.items.single.id, '1');
    });
  });

  group('groupExerciseEntriesByDate', () {
    test('groups today exercises only by default', () {
      final entries = [
        ExerciseEntry(
          id: '1',
          name: '走る',
          durationMin: 30,
          burnedKcal: 200,
          loggedAt: DateTime(2026, 7, 21, 7),
        ),
      ];

      final groups = groupExerciseEntriesByDate(
        entries,
        referenceDate: referenceDate,
      );

      expect(groups, hasLength(1));
      expect(groups.first.label, '今日');
    });
  });
}
