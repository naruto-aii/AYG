import 'package:ayg/screens/weight/weight_record_screen.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'prototype_ui5_fixtures.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await createPrototypeUi5Controller();

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: WeightRecordScreen(
        controller: controller,
        initialWeightKg: controller.profile?.weightKg,
      ),
    ),
  );
}
