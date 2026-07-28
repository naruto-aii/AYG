import 'package:ayg/screens/meal_template/meal_template_list_screen.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'prototype_meal_template_fixtures.dart';

/// 食事テンプレート一覧Screenshot用（テストデータ3件）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = createPrototypeMealTemplateController();

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: MealTemplateListScreen(controller: controller),
    ),
  );
}
