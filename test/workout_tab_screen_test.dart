import 'package:ayg/models/exercise_entry.dart';
import 'package:ayg/screens/workout/workout_tab_screen.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('workout tab shows a saved exercise for today', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final now = DateTime.now();
    controller.exerciseEntries.add(
      ExerciseEntry(
        id: 'walk',
        name: 'ウォーキング',
        durationMin: 30,
        burnedKcal: 500,
        grossKcal: 500,
        netKcal: 250,
        loggedAt: now,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: WorkoutTabScreen(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('運動'), findsWidgets);
    expect(find.text('ウォーキング'), findsOneWidget);
    expect(find.text('250'), findsOneWidget);
    expect(find.text('500'), findsNothing);
    expect(find.text('運動を追加'), findsOneWidget);
  });
}
