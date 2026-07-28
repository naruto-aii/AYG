import 'package:ayg/screens/meal_template/meal_template_form_screen.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'prototype_meal_template_fixtures.dart';

/// 食事テンプレート編集Screenshot用（構成食品3件）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = createPrototypeMealTemplateController();

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: MealTemplateFormScreen(
        controller: controller,
        templateId: prototypeMealTemplateFormId,
      ),
    ),
  );
}
