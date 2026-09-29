import 'package:flutter/material.dart';

import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_icons.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import '../meal_template/meal_template_list_screen.dart';
import '../saved_food/saved_food_list_screen.dart';
import '../workout_template/workout_template_screens.dart';

/// マイ食品（保存食品とテンプレートの入口）。
///
/// Figma: 17 マイ食品。Figma の「公開した食品」は保存食品一覧の中で
/// 公開状態ごとに見られるため、行としては置いていない。
class SettingsFoodMasterScreen extends StatelessWidget {
  const SettingsFoodMasterScreen({
    super.key,
    required this.controller,
    this.openFoodFactsService,
  });

  final AppController controller;
  final OpenFoodFactsService? openFoodFactsService;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'マイ食品',
            subtitle: '登録した食品とテンプレートをまとめて管理できます。',
          ),
          SettingsRow(
            icon: AppIcons.bookmark,
            title: '保存食品',
            subtitle: '自分で登録した食品・公開した食品',
            onTap: () => _push(
              context,
              SavedFoodListScreen(
                controller: controller,
                openFoodFactsService: openFoodFactsService,
              ),
            ),
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: AppIcons.template,
            title: '食事テンプレート',
            subtitle: 'よく食べる組み合わせ',
            onTap: () =>
                _push(context, MealTemplateListScreen(controller: controller)),
          ),
          const SizedBox(height: 8),
          SettingsRow(
            icon: AppIcons.dumbbell,
            title: '運動テンプレート',
            subtitle: 'よくする運動の組み合わせ',
            onTap: () => _push(
              context,
              WorkoutTemplateListScreen(controller: controller),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
