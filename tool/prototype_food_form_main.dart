import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/screens/food/food_form_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/state/app_controller.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import '../test/mocks/mock_health_repository.dart';

/// 食事追加画面Screenshot用。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final openFoodFactsService = OpenFoodFactsService(
    userAgent: OpenFoodFactsConfig.userAgent,
  );
  final controller = AppController(
    healthRepository: MockHealthRepository(isAvailable: false),
  );

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: FoodFormScreen(
        controller: controller,
        openFoodFactsService: openFoodFactsService,
      ),
    ),
  );
}
