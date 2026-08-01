import 'package:flutter/material.dart';

import '../../models/saved_food.dart';
import '../../services/saved_food_entry_builder.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../constants/app_strings.dart';
import '../../utils/nutrition_format.dart';
import '../../utils/macro_display.dart';
import '../../widgets/common/compact_macro_display.dart';
import '../../utils/saved_food_base_serving_format.dart';
import '../common/app_bottom_sheet.dart';
import '../common/app_text_field.dart';
import '../common/primary_button.dart';

BuildContext _rootSheetContext(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).context;
}

/// 保存済み / 公開食品から食事へ直接追加する数量入力シート。
Future<bool> showSavedFoodMealQuantitySheet({
  required BuildContext context,
  required AppController controller,
  required SavedFood food,
  DateTime? loggedAt,
}) async {
  final result = await showAppBottomSheet<bool>(
    context: _rootSheetContext(context),
    isScrollControlled: true,
    builder: (sheetContext) {
      return _SavedFoodMealQuantitySheet(
        controller: controller,
        food: food,
        loggedAt: loggedAt ?? DateTime.now(),
      );
    },
  );
  return result ?? false;
}

class _SavedFoodMealQuantitySheet extends StatefulWidget {
  const _SavedFoodMealQuantitySheet({
    required this.controller,
    required this.food,
    required this.loggedAt,
  });

  final AppController controller;
  final SavedFood food;
  final DateTime loggedAt;

  @override
  State<_SavedFoodMealQuantitySheet> createState() =>
      _SavedFoodMealQuantitySheetState();
}

class _SavedFoodMealQuantitySheetState
    extends State<_SavedFoodMealQuantitySheet> {
  static const _entryBuilder = SavedFoodEntryBuilder();

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _quantityController;
  bool _isSubmitting = false;
  bool _submitted = false;

  SavedFood get _food => widget.food;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: SavedFoodBaseServingFormat.formatQuantity(_food.baseAmount),
    );
    _quantityController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  double? get _consumedQuantity {
    return SavedFoodBaseServingFormat.parseQuantity(_quantityController.text);
  }

  Map<String, double?> get _scaledNutrients {
    final consumed = _consumedQuantity;
    if (consumed == null) {
      return const {};
    }
    return _entryBuilder.scaledNutrients(
      food: _food,
      consumedQuantity: consumed,
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting || _submitted) {
      return;
    }
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final consumed = _consumedQuantity;
    if (consumed == null) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.controller.addMealEntryFromSavedFoodMaster(
        food: _food,
        consumedQuantity: consumed,
        loggedAt: widget.loggedAt,
      );
      if (!mounted) {
        return;
      }
      _submitted = true;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('食事の追加に失敗しました: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final scaled = _scaledNutrients;
    final unitLabel = _food.baseUnit;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_food.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '基準：${SavedFoodBaseServingFormat.formatPerBaseLabel(
                    baseServingDefined: _food.baseServingDefined,
                    baseAmount: _food.baseAmount,
                    baseUnit: unitLabel,
                  )}',
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(AppStrings.macroNutritionInfoLabel),
                CompactMacroDisplay(
                  kcal: _food.kcalPerBase,
                  proteinG: _food.proteinPerBase,
                  fatG: _food.fatPerBase,
                  carbG: _food.carbPerBase,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: _quantityController,
                        label: '食べた量',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) => SavedFoodBaseServingFormat
                            .validateQuantity(value, label: '数量'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Padding(
                      padding: const EdgeInsets.only(top: 28),
                      child: Text(
                        unitLabel,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                if (scaled.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(AppStrings.macroRecordNutritionLabel),
                  CompactMacroDisplay(
                    kcal: scaled['kcal'],
                    proteinG: scaled['protein'],
                    fatG: scaled['fat'],
                    carbG: scaled['carb'],
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: _isSubmitting ? '追加中...' : 'この内容で追加',
                  loading: _isSubmitting,
                  onPressed: _isSubmitting || _submitted ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 基準量未設定の食品向けフォールバックダイアログ。
Future<void> showSavedFoodDirectAddBlockedDialog({
  required BuildContext context,
  VoidCallback? onOpenManualForm,
}) async {
  await showDialog<void>(
    context: _rootSheetContext(context),
    useRootNavigator: true,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('直接追加できません'),
        content: const Text(
          'この食品には基準量が設定されていないため、直接追加できません。',
        ),
        actions: [
          if (onOpenManualForm != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onOpenManualForm();
              },
              child: const Text('手入力フォームへ'),
            ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
        ],
      );
    },
  );
}
