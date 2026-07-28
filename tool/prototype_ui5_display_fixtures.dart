import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/models/food_entry.dart';
import 'package:ayg/models/food_entry_source.dart';
import 'package:ayg/models/food_unit_type.dart';
import 'package:ayg/utils/history_grouping.dart';

List<HistoryDateGroup<ExerciseEntry>> prototypeExerciseDateGroups() {
  final now = DateTime.now();
  return [
    HistoryDateGroup(
      date: now,
      label: '今日',
      items: [
        ExerciseEntry(
          id: 'ex-1',
          name: 'ランニング',
          durationMin: 30,
          burnedKcal: 280,
          loggedAt: now.subtract(const Duration(hours: 2)),
        ),
        ExerciseEntry(
          id: 'ex-2',
          name: '筋トレ',
          durationMin: 45,
          burnedKcal: 210,
          loggedAt: now.subtract(const Duration(hours: 5)),
        ),
      ],
    ),
    HistoryDateGroup(
      date: now.subtract(const Duration(days: 1)),
      label: '昨日',
      items: [
        ExerciseEntry(
          id: 'ex-3',
          name: 'ウォーキング',
          durationMin: 20,
          burnedKcal: 95,
          loggedAt: now.subtract(const Duration(days: 1, hours: 3)),
        ),
      ],
    ),
  ];
}

List<HistoryDateGroup<FoodEntry>> prototypeFoodDateGroups() {
  final now = DateTime.now();
  return [
    HistoryDateGroup(
      date: now,
      label: '今日',
      items: sortFoodEntriesByLoggedAt([
        FoodEntry(
          id: 'food-1',
          name: 'サラダチキン',
          kcalPerBase: 428,
          proteinPerBase: 50,
          fatPerBase: 8,
          carbPerBase: 2,
          baseAmount: 100,
          unitType: FoodUnitType.g,
          consumedAmount: 100,
          loggedAt: now.subtract(const Duration(hours: 1)),
        ),
        FoodEntry(
          id: 'food-2',
          name: '玄米おにぎり',
          kcalPerBase: 586,
          proteinPerBase: 12,
          fatPerBase: 4,
          carbPerBase: 120,
          baseAmount: 1,
          unitType: FoodUnitType.piece,
          consumedAmount: 1,
          loggedAt: now.subtract(const Duration(hours: 4)),
        ),
      ]),
    ),
    HistoryDateGroup(
      date: now.subtract(const Duration(days: 1)),
      label: '昨日',
      items: sortFoodEntriesByLoggedAt([
        FoodEntry(
          id: 'food-3',
          name: 'オートミール',
          kcalPerBase: 150,
          proteinPerBase: 5,
          fatPerBase: 3,
          carbPerBase: 27,
          baseAmount: 40,
          unitType: FoodUnitType.g,
          consumedAmount: 40,
          sourceType: FoodEntrySource.manual,
          loggedAt: now.subtract(const Duration(days: 1, hours: 2)),
        ),
      ]),
    ),
  ];
}
