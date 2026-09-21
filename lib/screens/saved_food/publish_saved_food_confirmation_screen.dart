import 'package:flutter/material.dart';

import '../../models/public_food_publish_match.dart';
import '../../models/saved_food.dart';
import '../../state/app_controller.dart';
import '../../constants/app_strings.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_display_labels.dart';
import '../../widgets/saved_food/public_food_match_card.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/warn_banner.dart';

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
    Widget danger(String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: AppTypography.bodyS.copyWith(color: AppColors.textDanger),
      ),
    );

    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '公開前の確認',
            subtitle: 'この内容で、ほかの人にも見えるようになります。',
          ),
          const WarnBanner(
            title: '公開すると取り消しに手間がかかります。',
            description:
                '公開後は他のユーザーが検索・利用できるようになります。'
                '作成者本人のみ元食品を編集・削除できます。'
                'すでに記録済みの食事内容は変更されません。',
          ),
          const SizedBox(height: 16),
          DesignCard(
            elevated: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('公開する内容', style: AppTypography.titleM),
                const SizedBox(height: 8),
                Text(food.name, style: AppTypography.titleL),
                const SizedBox(height: 8),
                _infoRow(
                  '基準量',
                  widget.controller.formatSavedFoodBaseLabel(food),
                ),
                _infoRow('kcal', formatNullableNutrient(food.kcalPerBase)),
                _infoRow(
                  AppStrings.macroProtein,
                  formatNullableNutrient(food.proteinPerBase),
                ),
                _infoRow(
                  AppStrings.macroFat,
                  formatNullableNutrient(food.fatPerBase),
                ),
                _infoRow(
                  AppStrings.macroCarb,
                  formatNullableNutrient(food.carbPerBase),
                ),
                if (food.brand != null) _infoRow('ブランド', food.brand!),
                if (food.barcode != null) _infoRow('バーコード', food.barcode!),
                _infoRow(
                  '登録元',
                  SavedFoodDisplayLabels.sourceType(food.sourceType),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('ほかの公開食品との比較', style: AppTypography.titleS),
          const SizedBox(height: 6),
          if (widget.duplicate != null) ...[
            danger('完全重複'),
            PublicFoodMatchCard.fromMatch(
              controller: widget.controller,
              match: widget.duplicate!,
            ),
          ] else
            Text(
              '完全重複: なし',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
          const SizedBox(height: 6),
          if (widget.similarFoods.isNotEmpty) ...[
            Text('類似食品', style: AppTypography.bodyS),
            ...widget.similarFoods.map(
              (match) => PublicFoodMatchCard.fromSimilar(
                controller: widget.controller,
                match: match,
              ),
            ),
          ] else
            Text(
              '類似食品: なし',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
          if (widget.manualMacroConsistent != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                widget.manualMacroConsistent! ? '4/9/4 整合: OK' : '4/9/4 整合: NG',
                style: AppTypography.bodyS.copyWith(
                  color: widget.manualMacroConsistent!
                      ? AppColors.textBrand
                      : AppColors.textDanger,
                ),
              ),
            ),
          ...widget.validationErrors.map(danger),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _confirmed,
            onChanged: widget.canPublish && !_isPublishing
                ? (value) => setState(() => _confirmed = value ?? false)
                : null,
            title: Text(
              '入力した食品情報と栄養値が正しいことを確認しました',
              style: AppTypography.bodyS.copyWith(color: AppColors.textPrimary),
            ),
          ),
          if (_errorMessage != null) danger(_errorMessage!),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: widget.canPublish && _confirmed && !_isPublishing
                ? _publish
                : null,
            child: Text(_isPublishing ? '公開中...' : '公開する'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _isPublishing
                ? null
                : () => Navigator.of(
                    context,
                  ).pop(PublishConfirmationAction.keepPrivate),
            child: const Text('非公開のままにする'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _isPublishing
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(PublishConfirmationAction.editInput),
                  child: const Text('入力内容を修正'),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _isPublishing
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(PublishConfirmationAction.cancel),
                  child: const Text('キャンセル'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: AppTypography.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.titleS,
            ),
          ),
        ],
      ),
    );
  }
}
