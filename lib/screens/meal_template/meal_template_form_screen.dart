import 'package:flutter/material.dart';

import '../../models/food_unit_type.dart';
import '../../models/meal_template_draft.dart';
import '../../models/saved_food.dart';
import '../../models/saved_food_entry_selection.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/macro_display.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/app_text_field.dart';
import '../saved_food/public_food_search_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/home_parts.dart';
import '../../widgets/design/icon_circle.dart';
import '../../widgets/design/settings_row.dart';

class MealTemplateFormScreen extends StatefulWidget {
  const MealTemplateFormScreen({
    super.key,
    required this.controller,
    this.templateId,
  });

  final AppController controller;
  final String? templateId;

  bool get isEditing => templateId != null;

  @override
  State<MealTemplateFormScreen> createState() => _MealTemplateFormScreenState();
}

class _MealTemplateFormScreenState extends State<MealTemplateFormScreen> {
  final _nameController = TextEditingController();
  final _items = <MealTemplateItemDraft>[];
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    final bundle = await widget.controller.getMealTemplateWithItems(
      widget.templateId!,
    );
    if (!mounted || bundle == null) {
      return;
    }
    _nameController.text = bundle.template.name;
    _items
      ..clear()
      ..addAll(
        bundle.items.map(
          (item) => MealTemplateItemDraft(
            itemId: item.itemId,
            savedFoodId: item.savedFoodId,
            sourceOwnerUserId: item.sourceOwnerUserId,
            name: item.name,
            baseAmount: item.baseAmount,
            unitType: item.unitType,
            kcalPerBase: item.kcalPerBase,
            proteinPerBase: item.proteinPerBase,
            fatPerBase: item.fatPerBase,
            carbPerBase: item.carbPerBase,
            consumedAmount: item.consumedAmount,
            sortOrder: item.sortOrder,
          ),
        ),
      );
    setState(() => _isLoading = false);
  }

  Future<void> _pickOwnSavedFood() async {
    final foods = await widget.controller.searchOwnSavedFoods('');
    if (!mounted || foods.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存済み食品がありません')));
      return;
    }

    final selected = await showModalBottomSheet<SavedFood>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          children: foods
              .map(
                (food) => ListTile(
                  title: Text(food.name),
                  subtitle: Text(
                    widget.controller.formatSavedFoodBaseLabel(food),
                  ),
                  onTap: () => Navigator.of(context).pop(food),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (selected != null) {
      _addFromSelection(
        widget.controller.selectSavedFoodForEntry(selected),
        savedFoodId: selected.foodId,
        sourceOwnerUserId: selected.ownerUserId,
      );
    }
  }

  Future<void> _pickPublicFood() async {
    final food = await Navigator.of(context).push<SavedFood>(
      MaterialPageRoute<SavedFood>(
        builder: (context) => PublicFoodSearchScreen(
          controller: widget.controller,
          selectForMealEntry: true,
        ),
      ),
    );
    if (food != null) {
      _addFromSelection(
        widget.controller.selectSavedFoodForEntry(food),
        savedFoodId: food.foodId,
        sourceOwnerUserId: food.ownerUserId,
      );
    }
  }

  void _addFromSelection(
    SavedFoodEntrySelection selection, {
    String? savedFoodId,
    String? sourceOwnerUserId,
  }) {
    setState(() {
      _items.add(
        MealTemplateItemDraft(
          savedFoodId: savedFoodId,
          sourceOwnerUserId: sourceOwnerUserId,
          name: selection.name,
          baseAmount: selection.baseAmount,
          unitType: selection.unitType,
          kcalPerBase: selection.kcalPerBase,
          proteinPerBase: selection.proteinPerBase,
          fatPerBase: selection.fatPerBase,
          carbPerBase: selection.carbPerBase,
          consumedAmount: selection.baseAmount,
          sortOrder: _items.length + 1,
        ),
      );
    });
  }

  Future<void> _addManualItem() async {
    final draft = await showDialog<MealTemplateItemDraft>(
      context: context,
      builder: (context) => _ManualItemDialog(sortOrder: _items.length + 1),
    );
    if (draft != null) {
      setState(() => _items.add(draft));
    }
  }

  double _itemMultiplier(MealTemplateItemDraft item) =>
      item.consumedAmount / item.baseAmount;

  double _itemTotalKcal(MealTemplateItemDraft item) =>
      (item.kcalPerBase ?? 0) * _itemMultiplier(item);

  double _itemTotalProtein(MealTemplateItemDraft item) =>
      (item.proteinPerBase ?? 0) * _itemMultiplier(item);

  double _itemTotalFat(MealTemplateItemDraft item) =>
      (item.fatPerBase ?? 0) * _itemMultiplier(item);

  double _itemTotalCarb(MealTemplateItemDraft item) =>
      (item.carbPerBase ?? 0) * _itemMultiplier(item);

  double get _totalKcal =>
      _items.fold(0, (sum, item) => sum + _itemTotalKcal(item));

  double get _totalProtein =>
      _items.fold(0, (sum, item) => sum + _itemTotalProtein(item));

  double get _totalFat =>
      _items.fold(0, (sum, item) => sum + _itemTotalFat(item));

  double get _totalCarb =>
      _items.fold(0, (sum, item) => sum + _itemTotalCarb(item));

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テンプレート名を入力してください')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食品を1件以上追加してください')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.controller.saveMealTemplate(
        draft: MealTemplateDraft(
          name: _nameController.text.trim(),
          items: _items,
        ),
        templateId: widget.templateId,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $error')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _showAddMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SettingsRow(
                icon: AppIcons.bookmark,
                title: '保存済み食品から追加',
                subtitle: '登録済みの食品から選ぶ',
                onTap: () => Navigator.of(context).pop('own'),
              ),
              const SizedBox(height: 8),
              SettingsRow(
                icon: AppIcons.search,
                title: '公開食品から追加',
                subtitle: 'みんなが登録した食品から探す',
                onTap: () => Navigator.of(context).pop('public'),
              ),
              const SizedBox(height: 8),
              SettingsRow(
                icon: AppIcons.pen,
                title: '手入力で追加',
                subtitle: '名前と栄養素を直接入れる',
                onTap: () => Navigator.of(context).pop('manual'),
              ),
            ],
          ),
        ),
      ),
    );
    switch (choice) {
      case 'own':
        await _pickOwnSavedFood();
      case 'public':
        await _pickPublicFood();
      case 'manual':
        await _addManualItem();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bottomBar: DesignButton(
        label: '保存する',
        showTrailingIcon: false,
        loading: _isSaving,
        onPressed: _isSaving || _isLoading ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: widget.isEditing ? 'テンプレートを編集' : 'テンプレートを作成',
            subtitle: 'よく食べる組み合わせに名前をつけて保存します。',
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            DesignFieldCard(
              icon: AppIcon(
                AppIcons.template,
                size: 24,
                color: IconCircle.foregroundOf(IconCircleTone.green),
              ),
              label: 'テンプレート名',
              child: DesignInputBox(
                child: DesignTextInput(
                  controller: _nameController,
                  hintText: '例）朝の定番セット',
                ),
              ),
            ),
            const SizedBox(height: 18),
            DesignSectionHeader(
              icon: AppIcons.meal,
              title: _items.isEmpty ? '登録する食品' : '登録する食品（${_items.length}）',
              actionLabel: '追加',
              onAction: _showAddMenu,
            ),
            const SizedBox(height: 4),
            if (_items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  '食品を追加してください',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              )
            else
              for (final entry in _items.asMap().entries)
                Dismissible(
                  key: ObjectKey(entry.value),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) =>
                      setState(() => _items.removeAt(entry.key)),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurfaceDanger,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const AppIcon(
                      AppIcons.trash,
                      size: 20,
                      color: AppColors.iconDanger,
                    ),
                  ),
                  child: DesignListRow(
                    icon: AppIcons.meal,
                    time:
                        '${entry.value.consumedAmount}${entry.value.unitType.label}',
                    title: entry.value.name,
                    value: formatNullableNutrient(_itemTotalKcal(entry.value)),
                  ),
                ),
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 12),
              DesignCard(
                elevated: false,
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
                          formatNullableNutrient(_totalKcal),
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
                        proteinG: _totalProtein,
                        fatG: _totalFat,
                        carbG: _totalCarb,
                      ),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '食品は左にスワイプすると外せます。',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 16),
            DesignButton(
              label: '食品を追加',
              style: DesignButtonStyle.outline,
              showTrailingIcon: false,
              onPressed: _showAddMenu,
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

class _ManualItemDialog extends StatefulWidget {
  const _ManualItemDialog({required this.sortOrder});

  final int sortOrder;

  @override
  State<_ManualItemDialog> createState() => _ManualItemDialogState();
}

class _ManualItemDialogState extends State<_ManualItemDialog> {
  final _nameController = TextEditingController();
  final _baseController = TextEditingController(text: '100');
  final _consumedController = TextEditingController(text: '100');
  final _kcalController = TextEditingController();
  FoodUnitType _unitType = FoodUnitType.g;

  @override
  void dispose() {
    _nameController.dispose();
    _baseController.dispose();
    _consumedController.dispose();
    _kcalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('手入力食品'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(controller: _nameController, label: '食品名'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _baseController,
              label: '基準量',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<FoodUnitType>(
              initialValue: _unitType,
              decoration: const InputDecoration(labelText: '単位'),
              items: FoodUnitType.values
                  .map(
                    (unit) =>
                        DropdownMenuItem(value: unit, child: Text(unit.label)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _unitType = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _consumedController,
              label: '摂取量',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _kcalController,
              label: 'kcal（基準量あたり）',
              keyboardType: TextInputType.number,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameController.text.trim();
            final base = double.tryParse(_baseController.text.trim());
            final consumed = double.tryParse(_consumedController.text.trim());
            if (name.isEmpty || base == null || consumed == null) {
              return;
            }
            Navigator.of(context).pop(
              MealTemplateItemDraft(
                name: name,
                baseAmount: base,
                unitType: _unitType,
                kcalPerBase: double.tryParse(_kcalController.text.trim()),
                consumedAmount: consumed,
                sortOrder: widget.sortOrder,
              ),
            );
          },
          child: const Text('追加'),
        ),
      ],
    );
  }
}
