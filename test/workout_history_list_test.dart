import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/utils/history_grouping.dart';
import 'package:ayg/widgets/history/workout_history_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workout history list shows effective net kcal not gross', (
    tester,
  ) async {
    final entry = ExerciseEntry(
      id: 'walk',
      name: 'ウォーキング',
      durationMin: 30,
      burnedKcal: 500,
      grossKcal: 500,
      netKcal: 250,
      loggedAt: DateTime(2026, 8, 1, 9),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutHistoryList(
            dateGroups: [
              HistoryDateGroup<ExerciseEntry>(
                date: DateTime(2026, 8, 1),
                label: '今日',
                items: [entry],
              ),
            ],
            onTapEntry: (_) {},
            onDeleteEntry: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('250 kcal'), findsOneWidget);
    expect(find.text('500 kcal'), findsNothing);
  });
}
