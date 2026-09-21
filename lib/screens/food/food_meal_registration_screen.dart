import 'package:flutter/material.dart';

import '../../models/meal_template.dart';
import '../../models/meal_template_draft.dart';
import '../../models/food_unit_type.dart';
import '../../state/app_controller.dart';
import '../../utils/macro_display.dart';
import '../meal_template/meal_template_list_screen.dart';
import '../meal_template/meal_template_picker_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/local_date.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/food_parts.dart';
import '../../widgets/design/home_parts.dart';
import '../../widgets/design/icon_circle.dart';

/// テンプレート展開後の複数食品を確認・編集して食事登録する画面。
class FoodMealRegistrationScreen extends StatefulWidget {
  const FoodMealRegistrationScreen({
    super.key,
    required this.controller,
    required this.mealGroupName,
    required this.initialItems,
    this.sourceTemplateId,
    this.initialLoggedAt,
  });

  final AppController controller;
  final String mealGroupName;
  final List<MealTemplateItemDraft> initialItems;
  final String? sourceTemplateId;
  final DateTime? initialLoggedAt;

  @override
  State<FoodMealRegistrationScreen> createState() =>
      _FoodMealRegistrationScreenState();
}

class _FoodMealRegistrationScreenState
    extends State<FoodMealRegistrationScreen> {
  late final List<MealTemplateItemDraft> _items;
  late DateTime _loggedAt;
  final _quantityControllers = <TextEditingController>[];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems.map((item) => item).toList();
    _loggedAt = (widget.initialLoggedAt ?? DateTime.now()).toLocal();
    for (final item in _items) {
      _quantityControllers.add(
        TextEditingController(text: item.consumedAmount.toString()),
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _quantityControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double _itemMultiplier(MealTemplateItemDraft item, int index) {
    final consumed = double.tryParse(_quantityControllers[index].text.trim());
    if (consumed == null || consumed <= 0 || item.baseAmount <= 0) {
      return 0;
    }
    return consumed / item.baseAmount;
  }

  double? _itemTotal(MealTemplateItemDraft item, int index, double? perBase) {
    if (perBase == null) {
      return null;
    }
    return perBase * _itemMultiplier(item, index);
  }

  List<MealTemplateItemDraft>? _buildDrafts() {
    final drafts = <MealTemplateItemDraft>[];
    for (var i = 0; i < _items.length; i++) {
      final consumed = double.tryParse(_quantityControllers[i].text.trim());
      if (consumed == null || consumed <= 0) {
        return null;
      }
      drafts.add(_items[i].copyWith(consumedAmount: consumed));
    }
    return drafts;
  }

  Future<void> _save() async {
    final drafts = _buildDrafts();
    if (drafts == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('すべての食品に有効な数量を入力してください')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.registerFoodMealFromDrafts(
        mealGroupName: widget.mealGroupName,
        items: drafts,
        loggedAt: _loggedAt,
        sourceTemplateId: widget.sourceTemplateId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  double _sum(double? Function(MealTemplateItemDraft item) perBase) {
    var total = 0.0;
    for (var i = 0; i < _items.length; i++) {
      total += _itemTotal(_items[i], i, perBase(_items[i])) ?? 0;
    }
    return total;
  }

  Future<void> _pickLoggedAt() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _loggedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_loggedAt),
    );
    if (pickedTime == null) {
      return;
    }
    setState(() {
      _loggedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Widget _itemCard(int i) {
    final item = _items[i];
    return DesignCard(
      elevated: false,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          IconCircle(
            size: 34,
            child: AppIcon(
              AppIcons.meal,
              size: 24,
              color: IconCircle.foregroundOf(IconCircleTone.green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleS,
                ),
                const SizedBox(height: 2),
                Text(
                  '基準: ${widget.controller.formatBaseAmountLabel(baseAmount: item.baseAmount, unitType: item.unitType)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatNullableNutrient(_itemTotal(item, i, item.kcalPerBase))} kcal ・ '
                  '${formatMacroSummaryInline(proteinG: _itemTotal(item, i, item.proteinPerBase), fatG: _itemTotal(item, i, item.fatPerBase), carbG: _itemTotal(item, i, item.carbPerBase))}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textBrand,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: MiniField(
              label: '摂取量',
              unit: item.unitType.label,
              child: TextField(
                controller: _quantityControllers[i],
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                style: AppTypography.bodyM.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final local = _loggedAt.toLocal();
    final totalKcal = _sum((item) => item.kcalPerBase);

    return DesignPage(
      bottomBar: DesignButton(
        label: '食事として登録',
        loading: _isSaving,
        onPressed: _isSaving ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'まとめて登録',
            subtitle: '内容を確認して、必要なら数量を直してください。',
          ),
          DesignSectionHeader(
            icon: AppIcons.template,
            title: '${widget.mealGroupName}（${_items.length}件）',
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < _items.length; i++) ...[
            _itemCard(i),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 4),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('合計', style: AppTypography.titleM),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      totalKcal.toStringAsFixed(0),
                      style: AppTypography.valueXl,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'kcal',
                      style: AppTypography.titleM.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatMacroSummaryInline(
                    proteinG: _sum((item) => item.proteinPerBase),
                    fatG: _sum((item) => item.fatPerBase),
                    carbG: _sum((item) => item.carbPerBase),
                  ),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DesignFieldCard(
            icon: AppIcon(
              AppIcons.calendar,
              size: 24,
              color: IconCircle.foregroundOf(IconCircleTone.green),
            ),
            label: '記録日時',
            child: DesignInputBox(
              onTap: _pickLoggedAt,
              child: Text(
                '${formatJapaneseDateWithWeekday(local)} '
                '${local.hour}:${local.minute.toString().padLeft(2, '0')}',
                style: AppTypography.bodyL.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// 指定テンプレートから [FoodMealRegistrationScreen] へ遷移する。
Future<bool?> openFoodMealRegistrationFromTemplate({
  required BuildContext context,
  required AppController controller,
  required MealTemplate template,
  DateTime? initialLoggedAt,
}) async {
  var bundle = await controller.getMealTemplateWithItems(template.templateId);
  if (bundle == null || !context.mounted) {
    return null;
  }

  var items = bundle.items;
  var issues = await controller.analyzeMealTemplateDependencies(items);
  while (issues.isNotEmpty) {
    final resolutions = await showMealTemplateDependencyDialog(
      context: context,
      controller: controller,
      issues: issues,
    );
    if (resolutions == null || !context.mounted) {
      return null;
    }
    items = controller.resolveMealTemplateItems(
      originalItems: bundle.items,
      resolutions: resolutions,
    );
    if (items.isEmpty) {
      return null;
    }
    issues = await controller.analyzeMealTemplateDependencies(items);
  }

  final drafts = items
      .map(MealTemplateItemDraft.fromTemplateItem)
      .toList(growable: false);

  if (!context.mounted) {
    return null;
  }

  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (context) => FoodMealRegistrationScreen(
        controller: controller,
        mealGroupName: template.name,
        initialItems: drafts,
        sourceTemplateId: template.templateId,
        initialLoggedAt: initialLoggedAt,
      ),
    ),
  );
}

/// テンプレートを選択し、依存関係を解決して [FoodMealRegistrationScreen] へ遷移する。
Future<bool?> openFoodMealRegistrationFromTemplatePicker({
  required BuildContext context,
  required AppController controller,
  DateTime? initialLoggedAt,
}) async {
  final template = await Navigator.of(context).push<MealTemplate>(
    MaterialPageRoute<MealTemplate>(
      builder: (context) => MealTemplatePickerScreen(controller: controller),
    ),
  );
  if (template == null || !context.mounted) {
    return null;
  }

  return openFoodMealRegistrationFromTemplate(
    context: context,
    controller: controller,
    template: template,
    initialLoggedAt: initialLoggedAt,
  );
}
