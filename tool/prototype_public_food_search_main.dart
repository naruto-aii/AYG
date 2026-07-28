import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'prototype_food_fixtures.dart';
import 'prototype_public_food_search_page.dart';

/// 公開食品検索Screenshot用（fixture repository + seed query で結果3件）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final controller = createPrototypePublicSearchController();
  final openFoodFactsService = OpenFoodFactsService(
    userAgent: OpenFoodFactsConfig.userAgent,
  );

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: PrototypePublicFoodSearchPage(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
      ),
    ),
  );
}
