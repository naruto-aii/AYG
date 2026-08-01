import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/macro_field.dart';
import '../../services/nutrition_value_calculator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/macro_display.dart';
import '../common/app_text_field.dart';
import 'macro_nutrition_input_controller.dart';

/// kcal / P / F / C 入力欄（Mobile / Web 共通）。
class MacroNutritionFields extends StatelessWidget {
  const MacroNutritionFields({
    super.key,
    required this.controller,
    required this.validator,
    this.readOnly = false,
  });

  final MacroNutritionInputController controller;
  final String? Function(String? value, String label) validator;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildField(
              context,
              field: MacroField.kcal,
              label: macroFieldInputLabel(MacroField.kcal),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildField(
              context,
              field: MacroField.protein,
              label: macroFieldInputLabel(MacroField.protein),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildField(
              context,
              field: MacroField.fat,
              label: macroFieldInputLabel(MacroField.fat),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildField(
              context,
              field: MacroField.carb,
              label: macroFieldInputLabel(MacroField.carb),
            ),
            if (controller.negativeMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                controller.negativeMessage!,
                style: const TextStyle(color: AppColors.error),
              ),
            ],
            if (controller.showExternalMismatchNotice) ...[
              const SizedBox(height: AppSpacing.sm),
              _ExternalMismatchNotice(controller: controller),
            ],
          ],
        );
      },
    );
  }

  Widget _buildField(
    BuildContext context, {
    required MacroField field,
    required String label,
  }) {
    final textController = controller.controllerFor(field);
    final source = controller.sourceOf(field);
    final suffix = source == MacroFieldSource.auto ? '（自動）' : null;

    return AppTextField(
      key: ValueKey('macro_field_${field.name}'),
      controller: textController,
      readOnly: readOnly,
      label: suffix == null ? label : '$label $suffix',
      suffixIcon: source == MacroFieldSource.auto
          ? Icon(
              Icons.auto_fix_high,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) => validator(value, label),
      onTap: () => controller.onFieldFocus(field),
      onChanged: (_) => controller.onFieldChanged(field),
    );
  }
}

class _ExternalMismatchNotice extends StatelessWidget {
  const _ExternalMismatchNotice({required this.controller});

  final MacroNutritionInputController controller;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    final parsed = (
      kcal: controller.parseOptional(MacroField.kcal),
      protein: controller.parseOptional(MacroField.protein),
      fat: controller.parseOptional(MacroField.fat),
      carb: controller.parseOptional(MacroField.carb),
    );

    final derivedKcal =
        parsed.protein != null && parsed.fat != null && parsed.carb != null
        ? NutritionValueCalculator.derivedKcal(
            protein: parsed.protein!,
            fat: parsed.fat!,
            carb: parsed.carb!,
          )
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.input,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.macroExternalMismatchTitle,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          if (parsed.kcal != null && derivedKcal != null) ...[
            const SizedBox(height: 4),
            Text(
              '${AppStrings.macroDisplayedKcalLabel}：${NutritionValueCalculator.formatForField(MacroField.kcal, parsed.kcal!)} kcal\n'
              '${AppStrings.macroDerivedKcalLabel}：${NutritionValueCalculator.formatForField(MacroField.kcal, derivedKcal)} kcal',
              style: TextStyle(color: color),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            AppStrings.macroExternalMismatchFootnote,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
