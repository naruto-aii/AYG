import 'package:flutter/material.dart';

import '../meal_template/meal_template_list_screen.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../saved_food/saved_food_list_screen.dart';

class SettingsFoodMasterScreen extends StatelessWidget {
  const SettingsFoodMasterScreen({
    super.key,
    required this.controller,
    this.openFoodFactsService,
  });

  final AppController controller;
  final OpenFoodFactsService? openFoodFactsService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('食品・食事テンプレート')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restaurant_menu_outlined),
              title: const Text('マイ食品'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => SavedFoodListScreen(
                      controller: controller,
                      openFoodFactsService: openFoodFactsService,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.view_list_outlined),
              title: const Text('食事テンプレート'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) =>
                        MealTemplateListScreen(controller: controller),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
