import 'package:flutter/material.dart';

import '../../models/public_food_publish_match.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../constants/app_strings.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../utils/saved_food_display_labels.dart';

class PublicFoodMatchCard extends StatelessWidget {
  const PublicFoodMatchCard({
    super.key,
    required this.controller,
    required this.food,
    required this.goodCount,
    required this.badCount,
    this.reason,
  });

  factory PublicFoodMatchCard.fromMatch({
    required AppController controller,
    required PublicFoodPublishMatch match,
    String? reason,
  }) {
    return PublicFoodMatchCard(
      controller: controller,
      food: match.food,
      goodCount: match.goodCount,
      badCount: match.badCount,
      reason: reason,
    );
  }

  factory PublicFoodMatchCard.fromSimilar({
    required AppController controller,
    required PublicFoodSimilarMatch match,
  }) {
    return PublicFoodMatchCard(
      controller: controller,
      food: match.food,
      goodCount: match.goodCount,
      badCount: match.badCount,
      reason: match.reason.label,
    );
  }

  final AppController controller;
  final SavedFood food;
  final int goodCount;
  final int badCount;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(food.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            CompactMacroDisplay(
              kcal: food.kcalPerBase,
              proteinG: food.proteinPerBase,
              fatG: food.fatPerBase,
              carbG: food.carbPerBase,
            ),
            Text('Good $goodCount / Bad $badCount'),
            Text('作成元: ${SavedFoodDisplayLabels.sourceType(food.sourceType)}'),
            Text('更新: ${_formatDateTime(food.updatedAt)}'),
            if (reason != null) Text('理由: $reason'),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }
}
