import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/saved_food.dart';
import '../state/app_controller.dart';
import '../widgets/saved_food/saved_food_meal_quantity_sheet.dart';

typedef PublicFoodMealAddManualFormOpener =
    void Function(BuildContext context, SavedFood food);

/// 公開食品検索から食事へ直接追加するフロー。
class PublicFoodMealAddFlow {
  const PublicFoodMealAddFlow._();

  static Future<bool> start({
    required BuildContext context,
    required AppController controller,
    required SavedFood food,
    PublicFoodMealAddManualFormOpener? onOpenManualForm,
    VoidCallback? onAdded,
  }) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    try {
      if (!food.baseServingDefined) {
        await showSavedFoodDirectAddBlockedDialog(
          context: rootContext,
          onOpenManualForm: onOpenManualForm == null
              ? null
              : () => onOpenManualForm(rootContext, food),
        );
        return false;
      }

      final added = await showSavedFoodMealQuantitySheet(
        context: rootContext,
        controller: controller,
        food: food,
      );
      if (added) {
        onAdded?.call();
      }
      return added;
    } catch (error, stackTrace) {
      debugPrint('PublicFoodMealAddFlow failed: $error\n$stackTrace');
      if (rootContext.mounted) {
        ScaffoldMessenger.of(rootContext).showSnackBar(
          const SnackBar(
            content: Text('食品を追加できませんでした。もう一度お試しください'),
          ),
        );
      }
      return false;
    }
  }
}
