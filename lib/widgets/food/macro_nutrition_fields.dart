import 'package:flutter/material.dart';

import '../../models/macro_field.dart';
import '../../services/nutrition_value_calculator.dart';
import 'macro_nutrition_input_controller.dart';

/// kcal / P / F / C 入力欄（Mobile / Web 共通）。
class MacroNutritionFields extends StatelessWidget {
  const MacroNutritionFields({
    super.key,
    required this.controller,
    required this.validator,
  });

  final MacroNutritionInputController controller;
  final String? Function(String? value, String label) validator;

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
              label: 'kcal（1単位あたり・任意）',
            ),
            const SizedBox(height: 16),
            _buildField(
              context,
              field: MacroField.protein,
              label: 'P（1単位あたり g・任意）',
            ),
            const SizedBox(height: 16),
            _buildField(
              context,
              field: MacroField.fat,
              label: 'F（1単位あたり g・任意）',
            ),
            const SizedBox(height: 16),
            _buildField(
              context,
              field: MacroField.carb,
              label: 'C（1単位あたり g・任意）',
            ),
            if (controller.negativeMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.negativeMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (controller.consistencyWarning != null) ...[
              const SizedBox(height: 12),
              _ConsistencyBanner(warning: controller.consistencyWarning!),
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

    return TextFormField(
      controller: textController,
      decoration: InputDecoration(
        labelText: suffix == null ? label : '$label $suffix',
        border: const OutlineInputBorder(),
        suffixIcon: source == MacroFieldSource.auto
            ? Icon(
                Icons.auto_fix_high,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (value) => validator(value, label),
      onTap: () => controller.onFieldFocus(field),
      onChanged: (_) => controller.onFieldChanged(field),
    );
  }
}

class _ConsistencyBanner extends StatelessWidget {
  const _ConsistencyBanner({required this.warning});

  final MacroConsistencyWarning warning;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.tertiary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '入力カロリーとPFCから計算した値に差があります。',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '入力値：${NutritionValueCalculator.formatForField(MacroField.kcal, warning.inputKcal)} kcal\n'
            'PFC換算：${NutritionValueCalculator.formatForField(MacroField.kcal, warning.derivedKcal)} kcal\n'
            '差：${NutritionValueCalculator.formatForField(MacroField.kcal, warning.differenceKcal)} kcal',
            style: TextStyle(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            '食物繊維・糖アルコール・表示丸め等により一致しない場合があります。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
