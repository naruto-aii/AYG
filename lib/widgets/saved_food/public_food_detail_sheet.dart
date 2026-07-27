import 'package:flutter/material.dart';

import '../../models/public_food_search_match.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_display_labels.dart';

Future<void> showPublicFoodDetailSheet({
  required BuildContext context,
  required AppController controller,
  required PublicFoodSearchMatch match,
  required bool selectForMealEntry,
  ValueChanged<SavedFood>? onUseForMeal,
  VoidCallback? onCopied,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _PublicFoodDetailSheet(
        controller: controller,
        match: match,
        selectForMealEntry: selectForMealEntry,
        onUseForMeal: onUseForMeal,
        onCopied: onCopied,
      );
    },
  );
}

class _PublicFoodDetailSheet extends StatefulWidget {
  const _PublicFoodDetailSheet({
    required this.controller,
    required this.match,
    required this.selectForMealEntry,
    this.onUseForMeal,
    this.onCopied,
  });

  final AppController controller;
  final PublicFoodSearchMatch match;
  final bool selectForMealEntry;
  final ValueChanged<SavedFood>? onUseForMeal;
  final VoidCallback? onCopied;

  @override
  State<_PublicFoodDetailSheet> createState() => _PublicFoodDetailSheetState();
}

class _PublicFoodDetailSheetState extends State<_PublicFoodDetailSheet> {
  bool _isCopying = false;

  SavedFood get _food => widget.match.food;

  Future<void> _copyToPrivate() async {
    if (_isCopying) {
      return;
    }
    setState(() => _isCopying = true);
    try {
      final copy = await widget.controller.copyPublicFoodToPrivate(_food);
      if (!mounted) {
        return;
      }
      widget.onCopied?.call();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('「${copy.name}」を自分用食品としてコピーしました')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('コピーに失敗しました: $error')));
    } finally {
      if (mounted) {
        setState(() => _isCopying = false);
      }
    }
  }

  void _useForMeal() {
    widget.onUseForMeal?.call(_food);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final food = _food;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(food.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '${widget.controller.formatSavedFoodBaseLabel(food)} · '
                '${formatNullableNutrient(food.kcalPerBase)}kcal · '
                'P${formatNullableNutrient(food.proteinPerBase)} '
                'F${formatNullableNutrient(food.fatPerBase)} '
                'C${formatNullableNutrient(food.carbPerBase)}',
              ),
              if (food.brand != null && food.brand!.isNotEmpty)
                Text('ブランド: ${food.brand}'),
              Text(
                '登録元: ${SavedFoodDisplayLabels.sourceType(food.sourceType)}',
              ),
              Text(
                'Good ${widget.match.goodCount} / Bad ${widget.match.badCount}',
              ),
              Text('更新: ${food.updatedAt.toLocal()} · v${food.version}'),
              const SizedBox(height: 8),
              const Text('ユーザー登録食品'),
              const SizedBox(height: 8),
              const Text(
                '評価は正確性を保証するものではありません',
                style: TextStyle(fontSize: 12),
              ),
              if (widget.match.hasLowRating) ...[
                const SizedBox(height: 8),
                Text(
                  '低い評価が多い食品です。基準量と栄養情報を確認してから利用してください。',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _useForMeal,
                child: Text(widget.selectForMealEntry ? '食事に追加' : '食事登録へ'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _isCopying ? null : _copyToPrivate,
                child: _isCopying
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('自分用食品としてコピー'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
