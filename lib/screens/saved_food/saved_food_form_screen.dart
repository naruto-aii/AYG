import 'package:flutter/material.dart';

import '../../models/food_unit_type.dart';
import '../../models/food_visibility.dart';
import '../../models/macro_field.dart';
import '../../models/saved_food.dart';
import '../../models/saved_food_draft.dart';
import '../../services/saved_food_version_policy.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_section_header.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/layout/app_constrained_bottom_bar.dart';
import '../../widgets/layout/app_form_constraint.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';
import '../../widgets/saved_food/confirm_public_food_update_dialog.dart';
import 'saved_food_publish_flow.dart';

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
  bool get _isPrivateFood =>
      widget.food == null || widget.food!.visibility == FoodVisibility.private;

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

  SavedFood? _buildUpdatedFood(SavedFoodDraft draft) {
    final existing = widget.food;
    if (existing == null) {
      return null;
    }
    return existing.copyWith(
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
    );
  }

  String? _nullableText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _save() async {
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
        final updated = _buildUpdatedFood(draft)!;
        if (existing.visibility == FoodVisibility.public &&
            SavedFoodVersionPolicy.requiresPublicUpdateConfirmation(
              existing,
              updated,
            )) {
          final confirmed = await showConfirmPublicFoodUpdateDialog(context);
          if (!confirmed) {
            return;
          }
          await widget.controller.updatePublishedSavedFood(
            updated,
            confirmedPublicUpdate: true,
          );
        } else if (existing.visibility == FoodVisibility.public) {
          await widget.controller.updatePublishedSavedFood(
            updated,
            confirmedPublicUpdate: false,
          );
        } else {
          await widget.controller.updateSavedFood(updated);
        }
      } else {
        await widget.controller.createSavedFood(draft);
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      _showMessage(widget.controller.publishErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _startPublish() async {
    final existing = widget.food;
    if (existing == null || existing.visibility != FoodVisibility.private) {
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSaving = true);
    SavedFood foodToPublish = existing;
    try {
      final draft = _buildDraft();
      if (draft != null &&
          (draft.name != existing.name ||
              draft.baseAmount != existing.baseAmount ||
              draft.unitType != existing.unitType ||
              draft.kcalPerBase != existing.kcalPerBase)) {
        foodToPublish = await widget.controller.updateSavedFood(
          _buildUpdatedFood(draft)!,
        );
      }
    } catch (error) {
      _showMessage(widget.controller.publishErrorMessage(error));
      setState(() => _isSaving = false);
      return;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    if (!mounted) {
      return;
    }

    final published = await startSavedFoodPublishFlow(
      context: context,
      controller: widget.controller,
      food: foodToPublish,
    );
    if (published && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _unpublish() async {
    final existing = widget.food;
    if (existing == null || existing.visibility != FoodVisibility.public) {
      return;
    }

    await confirmUnpublishSavedFood(
      context: context,
      controller: widget.controller,
      food: existing,
      onSuccess: () {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      },
    );
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
        child: AppFormConstraint(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                100,
              ),
              children: [
                if (_isPublicFood)
                  AppCard(
                    child: Row(
                      children: [
                        const Icon(Icons.public),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '公開食品',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text('version ${widget.food!.version}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_isPublicFood) const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionHeader(title: '基本情報'),
                      AppTextField(
                        controller: _nameController,
                        label: '食品名 *',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '食品名を入力してください';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: AppTextField(
                              controller: _baseAmountController,
                              label: '基準量 *',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: _validateRequiredNumber('基準量'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: DropdownButtonFormField<FoodUnitType>(
                              value: _unitType,
                              decoration: const InputDecoration(
                                labelText: '単位 *',
                              ),
                              items: FoodUnitType.values
                                  .map(
                                    (unit) => DropdownMenuItem(
                                      value: unit,
                                      child: Text(unit.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _unitType = value);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionHeader(title: '栄養'),
                      MacroNutritionFields(
                        controller: _macroInput,
                        validator: (value, label) =>
                            _validateOptionalNonNegativeNumber(label)(value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppSectionHeader(title: 'オプション'),
                      AppTextField(
                        controller: _brandController,
                        label: 'ブランド・メーカー',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _barcodeController,
                        label: 'バーコード',
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _supplementaryWeightController,
                        label: '補助重量・内容量',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppCard(
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: '保存範囲'),
                    child: Text(_isPublicFood ? '公開' : '非公開（private）'),
                  ),
                ),
                if (_isPrivateFood && widget.isEditing) ...[
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: '公開する',
                    icon: Icons.public,
                    onPressed:
                        _isSaving ||
                            widget.controller.isPublishOperationInProgress
                        ? null
                        : _startPublish,
                  ),
                ],
                if (_isPublicFood) ...[
                  const SizedBox(height: AppSpacing.md),
                  SecondaryButton(
                    label: '非公開にする',
                    icon: Icons.lock,
                    onPressed:
                        _isSaving ||
                            widget.controller.isPublishOperationInProgress
                        ? null
                        : _unpublish,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppConstrainedBottomBar(
        child: PrimaryButton(
          label: _isSaving ? '保存中...' : '保存',
          loading: _isSaving,
          onPressed: _isSaving ? null : _save,
        ),
      ),
    );
  }
}
