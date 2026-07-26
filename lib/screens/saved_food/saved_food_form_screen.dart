import 'package:flutter/material.dart';

import '../../models/food_unit_type.dart';
import '../../models/food_visibility.dart';
import '../../models/macro_field.dart';
import '../../models/saved_food.dart';
import '../../models/saved_food_draft.dart';
import '../../state/app_controller.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';
import '../../widgets/saved_food/confirm_public_food_update_dialog.dart';

class SavedFoodFormScreen extends StatefulWidget {
  const SavedFoodFormScreen({super.key, required this.controller, this.food});

  final AppController controller;
  final SavedFood? food;

  bool get isEditing => food != null;

  @override
  State<SavedFoodFormScreen> createState() => _SavedFoodFormScreenState();
}

class _SavedFoodFormScreenState extends State<SavedFoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _baseAmountController = TextEditingController(text: '100');
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _supplementaryWeightController = TextEditingController();
  late final MacroNutritionInputController _macroInput;

  FoodUnitType _unitType = FoodUnitType.g;
  bool _isSaving = false;

  bool get _isPublicFood => widget.food?.visibility == FoodVisibility.public;

  @override
  void initState() {
    super.initState();
    _macroInput = MacroNutritionInputController();
    final food = widget.food;
    if (food != null) {
      _nameController.text = food.name;
      _baseAmountController.text = food.baseAmount.toString();
      _unitType = food.unitType;
      _brandController.text = food.brand ?? '';
      _barcodeController.text = food.barcode ?? '';
      _supplementaryWeightController.text = food.supplementaryWeight ?? '';
      _macroInput.initializeFromNullable(
        kcal: food.kcalPerBase,
        protein: food.proteinPerBase,
        fat: food.fatPerBase,
        carb: food.carbPerBase,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _baseAmountController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _supplementaryWeightController.dispose();
    _macroInput.dispose();
    super.dispose();
  }

  SavedFoodDraft? _buildDraft() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }
    if (!_macroInput.prepareForSave()) {
      return null;
    }

    return SavedFoodDraft(
      name: _nameController.text.trim(),
      baseAmount: double.parse(_baseAmountController.text.trim()),
      unitType: _unitType,
      kcalPerBase: _macroInput.parseOptional(MacroField.kcal),
      proteinPerBase: _macroInput.parseOptional(MacroField.protein),
      fatPerBase: _macroInput.parseOptional(MacroField.fat),
      carbPerBase: _macroInput.parseOptional(MacroField.carb),
      brand: _nullableText(_brandController.text),
      barcode: normalizeEan13Barcode(_barcodeController.text.trim()),
      supplementaryWeight: _nullableText(_supplementaryWeightController.text),
    );
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
    if (_isPublicFood) {
      _showMessage('公開食品の編集は Phase 6D で対応予定です');
      return;
    }

    if (!_macroInput.prepareForSave()) {
      _showMessage(
        _macroInput.negativeMessage ?? '栄養素の値が整合していません。入力を見直してください。',
      );
      return;
    }

    final draft = _buildDraft();
    if (draft == null) {
      return;
    }

    if (draft.kcalPerBase == null ||
        draft.proteinPerBase == null ||
        draft.fatPerBase == null ||
        draft.carbPerBase == null) {
      _showMessage('kcal / P / F / C は必須です');
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (widget.isEditing) {
        final existing = widget.food!;
        if (existing.visibility == FoodVisibility.public) {
          final confirmed = await showConfirmPublicFoodUpdateDialog(context);
          if (!confirmed) {
            return;
          }
        }
        await widget.controller.updateSavedFood(
          existing.copyWith(
            name: draft.name,
            baseAmount: draft.baseAmount,
            unitType: draft.unitType,
            kcalPerBase: draft.kcalPerBase,
            proteinPerBase: draft.proteinPerBase,
            fatPerBase: draft.fatPerBase,
            carbPerBase: draft.carbPerBase,
            brand: draft.brand,
            barcode: draft.barcode,
            supplementaryWeight: draft.supplementaryWeight,
          ),
        );
      } else {
        await widget.controller.createSavedFood(draft);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage('保存に失敗しました: $error');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? Function(String?) _validateRequiredNumber(String label) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return '$label を入力してください';
      }
      final parsed = double.tryParse(value.trim());
      if (parsed == null || parsed <= 0) {
        return '$label は0より大きい数値を入力してください';
      }
      return null;
    };
  }

  String? Function(String?) _validateOptionalNonNegativeNumber(String label) {
    return (value) {
      if (value == null || value.trim().isEmpty) {
        return null;
      }
      final parsed = double.tryParse(value.trim());
      if (parsed == null || parsed < 0) {
        return '$label は0以上の数値を入力してください';
      }
      return null;
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '食品を編集' : '食品を追加')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              if (_isPublicFood)
                Card(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('公開食品'),
                    subtitle: Text(
                      '公開食品の更新は Phase 6D で有効化予定です。'
                      '現時点では内容の確認のみ可能です。',
                    ),
                  ),
                ),
              TextFormField(
                controller: _nameController,
                readOnly: _isPublicFood,
                decoration: const InputDecoration(
                  labelText: '食品名 *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '食品名を入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _baseAmountController,
                      readOnly: _isPublicFood,
                      decoration: const InputDecoration(
                        labelText: '基準量 *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: _validateRequiredNumber('基準量'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<FoodUnitType>(
                      value: _unitType,
                      decoration: const InputDecoration(
                        labelText: '単位 *',
                        border: OutlineInputBorder(),
                      ),
                      items: FoodUnitType.values
                          .map(
                            (unit) => DropdownMenuItem(
                              value: unit,
                              child: Text(unit.label),
                            ),
                          )
                          .toList(),
                      onChanged: _isPublicFood
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _unitType = value);
                              }
                            },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              MacroNutritionFields(
                controller: _macroInput,
                readOnly: _isPublicFood,
                validator: (value, label) =>
                    _validateOptionalNonNegativeNumber(label)(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _brandController,
                readOnly: _isPublicFood,
                decoration: const InputDecoration(
                  labelText: 'ブランド・メーカー',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _barcodeController,
                readOnly: _isPublicFood,
                decoration: const InputDecoration(
                  labelText: 'バーコード',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _supplementaryWeightController,
                readOnly: _isPublicFood,
                decoration: const InputDecoration(
                  labelText: '補助重量・内容量',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: '保存範囲',
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  widget.food?.visibility == FoodVisibility.public
                      ? '公開'
                      : '非公開（private）',
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _isSaving || _isPublicFood ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(_isSaving ? '保存中...' : '保存'),
            ),
          ),
        ),
      ),
    );
  }
}
