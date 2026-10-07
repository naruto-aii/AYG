import 'package:flutter/material.dart';

import '../../models/food_entry.dart';
import '../../services/recent_foods.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import 'recent_food_quantity_screen.dart';

/// 直近3日の食品を1件ずつ選ぶ。一括では登録しない。
class RecentFoodsScreen extends StatelessWidget {
  const RecentFoodsScreen({
    super.key,
    required this.controller,
    this.now,
    this.foods,
  });

  final AppController controller;
  final DateTime? now;
  final List<RecentFood>? foods;

  @override
  Widget build(BuildContext context) {
    final items =
        foods ?? recentFoods(controller.foodEntries, now ?? DateTime.now());
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '直近3日の食品',
            subtitle: '選んだ食品だけを追加します。前回と同じ量かを確認します。',
          ),
          if (items.isEmpty)
            Text('直近3日に登録した食品はありません', style: AppTypography.bodyS)
          else
            for (final food in items) ...[
              DesignCard(
                onTap: () => _choose(context, food.latest),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(food.latest.name, style: AppTypography.titleM),
                          const SizedBox(height: 2),
                          Text(
                            '前回 ${formatFoodAmount(food.latest)}',
                            style: AppTypography.bodyS.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const DesignIcon(
                      Symbols.chevron_right_rounded,
                      size: 16,
                      color: AppColors.iconMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Future<void> _choose(BuildContext context, FoodEntry source) async {
    final same = await showDialog<bool>(
      routeSettings: const RouteSettings(name: 'recent_foods_screen_showDialog_0'),
      context: context,
      builder: (context) => AlertDialog(
        title: Text(source.name),
        content: Text('前回と同じ量（${formatFoodAmount(source)}）で登録しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('違う'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('同じ'),
          ),
        ],
      ),
    );
    if (same == null || !context.mounted) {
      return;
    }
    if (same) {
      final added = await controller.repeatRecentFood(
        source,
        loggedAt: now ?? DateTime.now(),
      );
      if (!context.mounted) {
        return;
      }
      if (added) {
        Navigator.of(context).pop(true);
      }
      return;
    }
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
      settings: const RouteSettings(name: 'recent_foods_screen_MaterialPageRoute_0'),
        builder: (context) => RecentFoodQuantityScreen(
          controller: controller,
          source: source,
          loggedAt: now ?? DateTime.now(),
        ),
      ),
    );
    if (added == true && context.mounted) {
      Navigator.of(context).pop(true);
    }
  }
}
