import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/screens/settings/settings_screen.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'prototype_ui5_fixtures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await createPrototypeUi5Controller();
  final authRepository = createPrototypeUi5AuthRepository();
  final openFoodFactsService = OpenFoodFactsService(
    userAgent: OpenFoodFactsConfig.userAgent,
  );

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: SettingsScreen(
        controller: controller,
        authenticationRepository: authRepository,
        openFoodFactsService: openFoodFactsService,
        hideHealthSettings: true,
      ),
    ),
  );
}
