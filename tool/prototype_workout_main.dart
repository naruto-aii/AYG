import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/history/workout_history_list.dart';
import 'package:flutter/material.dart';

import 'prototype_ui5_display_fixtures.dart';
import 'prototype_ui5_fixtures.dart';

/// 運動画面Screenshot用（履歴3件）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await createPrototypeUi5Controller();

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('運動'),
          actions: [
            Semantics(
              label: '運動追加',
              button: true,
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: WorkoutHistoryList(
            dateGroups: prototypeExerciseDateGroups(),
            onTapEntry: (_) {},
            onDeleteEntry: (_) {},
          ),
        ),
      ),
    ),
  );
}
