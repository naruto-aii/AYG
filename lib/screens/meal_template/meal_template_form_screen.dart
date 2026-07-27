import 'package:flutter/material.dart';

import '../../models/food_unit_type.dart';
import '../../models/meal_template_draft.dart';
import '../../models/saved_food.dart';
import '../../models/saved_food_entry_selection.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../saved_food/public_food_search_screen.dart';

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
  final _formKey = GlobalKey<FormState>();
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

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? 'テンプレート編集' : 'テンプレート作成')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'テンプレート名',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'テンプレート名を入力してください';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _pickOwnSavedFood,
                        child: const Text('保存済み食品'),
                      ),
                      OutlinedButton(
                        onPressed: _pickPublicFood,
                        child: const Text('公開食品'),
                      ),
                      OutlinedButton(
                        onPressed: _addManualItem,
                        child: const Text('手入力'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._items.asMap().entries.map((entry) {
                    final item = entry.value;
                    return Card(
                      child: ListTile(
                        title: Text(item.name),
                        subtitle: Text(
                          '${item.consumedAmount}${item.unitType.label} · '
                          '${formatNullableNutrient((item.kcalPerBase ?? 0) * item.consumedAmount / item.baseAmount)}kcal',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              setState(() => _items.removeAt(entry.key)),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ),
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
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '食品名'),
            ),
            TextField(
              controller: _baseController,
              decoration: const InputDecoration(labelText: '基準量'),
              keyboardType: TextInputType.number,
            ),
            DropdownButtonFormField<FoodUnitType>(
              initialValue: _unitType,
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
            TextField(
              controller: _consumedController,
              decoration: const InputDecoration(labelText: '摂取量'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: _kcalController,
              decoration: const InputDecoration(labelText: 'kcal（基準量あたり）'),
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
