import 'package:flutter/material.dart';

import '../../models/public_food_rating_view.dart';
import '../../models/public_food_search_match.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_display_labels.dart';
import '../common/app_bottom_sheet.dart';
import 'block_food_creator_dialog.dart';
import 'public_food_rating_bar.dart';
import 'public_food_report_dialog.dart';

Future<void> showPublicFoodDetailSheet({
  required BuildContext context,
  required AppController controller,
  required PublicFoodSearchMatch match,
  required bool selectForMealEntry,
  ValueChanged<SavedFood>? onUseForMeal,
  VoidCallback? onCopied,
  VoidCallback? onBlocked,
}) async {
  await showAppBottomSheet<void>(
    context: context,
    builder: (sheetContext) {
      return _PublicFoodDetailSheet(
        controller: controller,
        match: match,
        selectForMealEntry: selectForMealEntry,
        onUseForMeal: onUseForMeal,
        onCopied: onCopied,
        onBlocked: onBlocked,
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
    this.onBlocked,
  });

  final AppController controller;
  final PublicFoodSearchMatch match;
  final bool selectForMealEntry;
  final ValueChanged<SavedFood>? onUseForMeal;
  final VoidCallback? onCopied;
  final VoidCallback? onBlocked;

  @override
  State<_PublicFoodDetailSheet> createState() => _PublicFoodDetailSheetState();
}

class _PublicFoodDetailSheetState extends State<_PublicFoodDetailSheet> {
  bool _isCopying = false;
  bool _hasReported = false;
  bool _isCreatorBlocked = false;
  bool _isLoadingMeta = true;
  PublicFoodRatingView? _ratingView;

  SavedFood get _food => widget.match.food;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final ratingView = await widget.controller.getPublicFoodRatingView(_food);
    final hasReported = await widget.controller.hasReportedPublicFood(_food);
    final isBlocked = await widget.controller.isFoodCreatorBlocked(
      _food.ownerUserId,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _ratingView = ratingView;
      _hasReported = hasReported;
      _isCreatorBlocked = isBlocked;
      _isLoadingMeta = false;
    });
  }

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

  Future<void> _report() async {
    final submitted = await showPublicFoodReportDialog(
      context: context,
      controller: widget.controller,
      food: _food,
    );
    if (submitted && mounted) {
      setState(() => _hasReported = true);
    }
  }

  Future<void> _toggleBlock() async {
    if (_isCreatorBlocked) {
      final unblocked = await confirmUnblockFoodCreator(
        context: context,
        controller: widget.controller,
        creatorUserId: _food.ownerUserId,
      );
      if (unblocked && mounted) {
        setState(() => _isCreatorBlocked = false);
      }
      return;
    }

    final blocked = await confirmBlockFoodCreator(
      context: context,
      controller: widget.controller,
      creatorUserId: _food.ownerUserId,
    );
    if (blocked && mounted) {
      setState(() => _isCreatorBlocked = true);
      widget.onBlocked?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = _food;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final canModerate =
        widget.controller.isAuthenticated &&
        food.ownerUserId != widget.controller.currentOwnerUserId;

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
              Text('更新: ${food.updatedAt.toLocal()} · v${food.version}'),
              const SizedBox(height: 8),
              const Text('ユーザー登録食品'),
              const SizedBox(height: 12),
              if (_isLoadingMeta)
                const Center(child: CircularProgressIndicator())
              else if (_ratingView != null)
                PublicFoodRatingBar(
                  controller: widget.controller,
                  food: food,
                  initialView: _ratingView!,
                  onViewChanged: (view) => setState(() => _ratingView = view),
                ),
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
              if (canModerate) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _hasReported ? null : _report,
                  child: Text(_hasReported ? '通報済み' : '通報'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _toggleBlock,
                  child: Text(_isCreatorBlocked ? 'ブロック解除' : '作成者をブロック'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
