import 'package:flutter/material.dart';

import '../../models/public_food_publish_match.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../constants/app_strings.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/macro_display.dart';
import '../../utils/saved_food_display_labels.dart';
import '../../widgets/saved_food/public_food_match_card.dart';

enum PublishConfirmationAction { publish, keepPrivate, editInput, cancel }

class PublishSavedFoodConfirmationScreen extends StatefulWidget {
  const PublishSavedFoodConfirmationScreen({
    super.key,
    required this.controller,
    required this.food,
    this.duplicate,
    this.similarFoods = const [],
    required this.validationErrors,
    this.manualMacroConsistent,
  });

  final AppController controller;
  final SavedFood food;
  final PublicFoodPublishMatch? duplicate;
  final List<PublicFoodSimilarMatch> similarFoods;
  final List<String> validationErrors;
  final bool? manualMacroConsistent;

  bool get canPublish =>
      duplicate == null &&
      validationErrors.isEmpty &&
      (manualMacroConsistent ?? true);

  @override
  State<PublishSavedFoodConfirmationScreen> createState() =>
      _PublishSavedFoodConfirmationScreenState();
}

class _PublishSavedFoodConfirmationScreenState
    extends State<PublishSavedFoodConfirmationScreen> {
  bool _confirmed = false;
  bool _isPublishing = false;
  String? _errorMessage;

  Future<void> _publish() async {
    if (!_confirmed || !widget.canPublish || _isPublishing) {
      return;
    }

    setState(() {
      _isPublishing = true;
      _errorMessage = null;
    });

    try {
      await widget.controller.publishSavedFood(widget.food.foodId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(PublishConfirmationAction.publish);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = widget.controller.publishErrorMessage(error);
        _isPublishing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return Scaffold(
      appBar: AppBar(title: const Text('公開前確認')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(food.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _infoRow('基準量', widget.controller.formatSavedFoodBaseLabel(food)),
            _infoRow('kcal', formatNullableNutrient(food.kcalPerBase)),
            _infoRow(AppStrings.macroProtein, formatNullableNutrient(food.proteinPerBase)),
            _infoRow(AppStrings.macroFat, formatNullableNutrient(food.fatPerBase)),
            _infoRow(AppStrings.macroCarb, formatNullableNutrient(food.carbPerBase)),
            if (food.brand != null) _infoRow('ブランド', food.brand!),
            if (food.barcode != null) _infoRow('バーコード', food.barcode!),
            _infoRow(
              'sourceType',
              SavedFoodDisplayLabels.sourceType(food.sourceType),
            ),
            const SizedBox(height: 16),
            if (widget.duplicate != null) ...[
              Text(
                '完全重複',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              PublicFoodMatchCard.fromMatch(
                controller: widget.controller,
                match: widget.duplicate!,
              ),
            ] else
              const Text('完全重複: なし'),
            const SizedBox(height: 12),
            if (widget.similarFoods.isNotEmpty) ...[
              const Text('類似食品'),
              ...widget.similarFoods.map(
                (match) => PublicFoodMatchCard.fromSimilar(
                  controller: widget.controller,
                  match: match,
                ),
              ),
            ] else
              const Text('類似食品: なし'),
            const SizedBox(height: 12),
            if (widget.manualMacroConsistent != null)
              Text(
                widget.manualMacroConsistent! ? '4/9/4 整合: OK' : '4/9/4 整合: NG',
                style: TextStyle(
                  color: widget.manualMacroConsistent!
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            if (widget.validationErrors.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...widget.validationErrors.map(
                (error) => Text(
                  error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text(
              '公開後は他のユーザーが検索・利用できるようになります。'
              '作成者本人のみ元食品を編集・削除できます。'
              'すでに記録済みの食事内容は変更されません。',
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmed,
              onChanged: widget.canPublish && !_isPublishing
                  ? (value) => setState(() => _confirmed = value ?? false)
                  : null,
              title: const Text('入力した食品情報と栄養値が正しいことを確認しました'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.canPublish && _confirmed && !_isPublishing
                  ? _publish
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_isPublishing ? '公開中...' : '公開する'),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isPublishing
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(PublishConfirmationAction.keepPrivate),
              child: const Text('privateのまま保存'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _isPublishing
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(PublishConfirmationAction.editInput),
              child: const Text('入力内容を修正'),
            ),
            TextButton(
              onPressed: _isPublishing
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(PublishConfirmationAction.cancel),
              child: const Text('キャンセル'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
