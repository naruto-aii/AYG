import 'package:flutter/material.dart';

import '../../models/meal_template.dart';
import '../../models/meal_template_apply.dart';
import '../../models/meal_template_draft.dart';
import '../../models/food_unit_type.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../widgets/common/logged_at_picker_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_constrained_bottom_bar.dart';
import '../../widgets/layout/app_form_constraint.dart';
import '../meal_template/meal_template_list_screen.dart';
import '../meal_template/meal_template_picker_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.mealGroupName} を登録')),
      body: SafeArea(
        child: AppFormConstraint(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              AppSpacing.md,
              AppSpacing.screenPadding,
              100,
            ),
            children: [
              LoggedAtPickerField(
                loggedAt: _loggedAt,
                onChanged: (value) => setState(() => _loggedAt = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '登録する食品 (${_items.length}件)',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (var i = 0; i < _items.length; i++) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _items[i].name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        '基準: ${widget.controller.formatBaseAmountLabel(baseAmount: _items[i].baseAmount, unitType: _items[i].unitType)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _quantityControllers[i],
                        label: '摂取量（${_items[i].unitType.label}）',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      CompactMacroDisplay(
                        kcal: _itemTotal(_items[i], i, _items[i].kcalPerBase),
                        proteinG: _itemTotal(
                          _items[i],
                          i,
                          _items[i].proteinPerBase,
                        ),
                        fatG: _itemTotal(_items[i], i, _items[i].fatPerBase),
                        carbG: _itemTotal(_items[i], i, _items[i].carbPerBase),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppConstrainedBottomBar(
        child: PrimaryButton(
          label: '食事として登録',
          loading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
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
