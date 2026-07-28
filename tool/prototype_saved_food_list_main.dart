import 'package:ayg/screens/saved_food/saved_food_list_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'prototype_food_fixtures.dart';

/// 保存済み食品一覧Screenshot用（テストデータ3件）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = await createPrototypeSavedFoodListController();
  final openFoodFactsService = OpenFoodFactsService(
    userAgent: OpenFoodFactsConfig.userAgent,
  );

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: SavedFoodListScreen(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
      ),
    ),
  );
}
