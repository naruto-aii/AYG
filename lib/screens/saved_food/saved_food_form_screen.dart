import 'package:flutter/material.dart';

import '../../models/food_unit_type.dart';
import '../../models/food_visibility.dart';
import '../../models/macro_field.dart';
import '../../models/saved_food.dart';
import '../../models/saved_food_draft.dart';
import '../../services/saved_food_version_policy.dart';
import '../../state/app_controller.dart';
import '../../constants/app_strings.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/saved_food_base_serving_format.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/food/macro_nutrition_fields.dart';
import '../../widgets/food/macro_nutrition_input_controller.dart';
import '../../widgets/saved_food/confirm_public_food_update_dialog.dart';
import '../../widgets/saved_food/serving_amount_fields.dart';
import 'saved_food_publish_flow.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/design_segment.dart';

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
  final _servingUnitController = TextEditingController();
  final _brandController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _supplementaryWeightController = TextEditingController();
  late final MacroNutritionInputController _macroInput;

  bool _isSaving = false;
  FoodVisibility _createVisibility = FoodVisibility.private;

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
      _baseAmountController.text = SavedFoodBaseServingFormat.formatQuantity(
        food.baseAmount,
      );
      _servingUnitController.text = food.servingUnitLabel ?? '';
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
    _servingUnitController.dispose();
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

    final baseAmount = SavedFoodBaseServingFormat.parseQuantity(
      _baseAmountController.text,
    );
    final servingUnit = SavedFoodBaseServingFormat.parseUnit(
      _servingUnitController.text,
    );
    if (baseAmount == null || servingUnit == null) {
      return null;
    }

    return SavedFoodDraft(
      name: _nameController.text.trim(),
      baseAmount: baseAmount,
      servingUnitLabel: servingUnit,
      unitType: FoodUnitTypeX.inferFromUnitLabel(servingUnit),
      kcalPerBase: _macroInput.parseOptional(MacroField.kcal),
      proteinPerBase: _macroInput.parseOptional(MacroField.protein),
      fatPerBase: _macroInput.parseOptional(MacroField.fat),
      carbPerBase: _macroInput.parseOptional(MacroField.carb),
      brand: _nullableText(_brandController.text),
      barcode: normalizeEan13Barcode(_barcodeController.text.trim()),
      supplementaryWeight: _nullableText(_supplementaryWeightController.text),
      visibility: _createVisibility,
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
      servingUnitLabel: draft.servingUnitLabel,
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
      _showMessage(AppStrings.macroNutrientsRequiredShort);
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
              draft.servingUnitLabel != existing.servingUnitLabel ||
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

  Widget _section(String title, List<Widget> children) {
    return DesignCard(
      elevated: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.titleM),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isSaving || widget.controller.isPublishOperationInProgress;

    return DesignPage(
      bottomBar: DesignButton(
        label: _isSaving ? '保存中...' : '保存する',
        showTrailingIcon: false,
        loading: _isSaving,
        onPressed: _isSaving ? null : _save,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesignTitleBlock(
              title: widget.isEditing ? '食品を編集' : '食品を登録',
              subtitle: '基準量あたりの栄養素を入れておきます。',
            ),
            if (_isPublicFood) ...[
              DesignCard(
                elevated: false,
                color: AppColors.bgSurfaceGreenSoft,
                child: Row(
                  children: [
                    const AppIcon(
                      AppIcons.shield,
                      size: 24,
                      color: AppColors.iconPrimary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '公開中の食品です（version ${widget.food!.version}）',
                        style: AppTypography.titleS,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            _section('基本情報', [
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
              const SizedBox(height: 12),
              ServingAmountFields(
                quantityController: _baseAmountController,
                unitController: _servingUnitController,
              ),
            ]),
            const SizedBox(height: 12),
            _section('基準量あたりの栄養素', [
              MacroNutritionFields(
                controller: _macroInput,
                compact: true,
                validator: (value, label) =>
                    _validateOptionalNonNegativeNumber(label)(value),
              ),
            ]),
            const SizedBox(height: 12),
            _section('オプション', [
              AppTextField(controller: _brandController, label: 'ブランド・メーカー'),
              const SizedBox(height: 12),
              AppTextField(
                controller: _barcodeController,
                label: 'バーコード',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _supplementaryWeightController,
                label: '補助重量・内容量',
              ),
            ]),
            const SizedBox(height: 18),
            Text('公開範囲', style: AppTypography.titleS),
            const SizedBox(height: 10),
            if (!widget.isEditing) ...[
              DesignSegmentGroup<FoodVisibility>(
                values: const [FoodVisibility.private, FoodVisibility.public],
                labelOf: (v) => v == FoodVisibility.public ? '公開' : '非公開',
                selected: _createVisibility,
                onChanged: (v) => setState(() => _createVisibility = v),
              ),
              const SizedBox(height: 8),
              Text(
                _createVisibility == FoodVisibility.public
                    ? '公開すると、ほかの人の検索結果にも出るようになります。'
                    : 'あなただけが利用できます。公開食品検索には表示されません。',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ] else ...[
              Text(
                _isPublicFood ? '公開中' : '非公開',
                style: AppTypography.bodyM.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              if (_isPrivateFood)
                DesignButton(
                  label: '公開する',
                  style: DesignButtonStyle.outline,
                  showTrailingIcon: false,
                  onPressed: busy ? null : _startPublish,
                ),
              if (_isPublicFood)
                DesignButton(
                  label: '非公開にする',
                  style: DesignButtonStyle.secondary,
                  showTrailingIcon: false,
                  onPressed: busy ? null : _unpublish,
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
