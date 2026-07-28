import 'package:ayg/config/open_food_facts_config.dart';
import 'package:ayg/services/open_food_facts_service.dart';
import 'package:ayg/theme/app_theme.dart';
import 'package:ayg/widgets/history/food_history_list.dart';
import 'package:flutter/material.dart';

import 'prototype_ui5_display_fixtures.dart';
import 'prototype_ui5_fixtures.dart';

/// 食事（分析）画面Screenshot用（履歴3件）。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await createPrototypeUi5Controller();
  OpenFoodFactsService(userAgent: OpenFoodFactsConfig.userAgent);

  runApp(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('食事'),
          actions: [
            Semantics(
              label: '食事追加',
              button: true,
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.add),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: FoodHistoryList(
            dateGroups: prototypeFoodDateGroups(),
            onTapEntry: (_) {},
            onDeleteEntry: (_) {},
          ),
        ),
      ),
    ),
  );
}
