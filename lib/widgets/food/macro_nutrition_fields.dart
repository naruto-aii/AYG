import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/macro_field.dart';
import '../../services/nutrition_value_calculator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/macro_display.dart';
import '../common/app_text_field.dart';
import '../design/food_parts.dart';
import 'macro_nutrition_input_controller.dart';

/// kcal / P / F / C 入力欄（Mobile / Web 共通）。
class MacroNutritionFields extends StatelessWidget {
  const MacroNutritionFields({
    super.key,
    required this.controller,
    required this.validator,
    this.readOnly = false,
    this.compact = false,
  });

  final MacroNutritionInputController controller;
  final String? Function(String? value, String label) validator;
  final bool readOnly;

  /// Figma の「栄養素」行（MiniField 4 つ）で並べる。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final field in MacroField.values) ...[
                    if (field != MacroField.kcal) const SizedBox(width: 8),
                    Expanded(child: _buildMiniField(field)),
                  ],
                ],
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
        }

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

  /// Figma: 栄養素の MiniField。自動計算された欄は文字色で示す。
  Widget _buildMiniField(MacroField field) {
    final textController = controller.controllerFor(field);
    final isAuto = controller.sourceOf(field) == MacroFieldSource.auto;

    return MiniField(
      label: isAuto
          ? '${macroFieldShortLabel(field)}（自動）'
          : macroFieldShortLabel(field),
      unit: field == MacroField.kcal ? 'kcal' : 'g',
      child: TextField(
        key: ValueKey('macro_field_${field.name}'),
        controller: textController,
        readOnly: readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onTap: () => controller.onFieldFocus(field),
        onChanged: (_) => controller.onFieldChanged(field),
        style: AppTypography.bodyM.copyWith(
          color: isAuto ? AppColors.textBrand : AppColors.textPrimary,
        ),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          hintText: '0',
        ),
      ),
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
