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
            if (controller.showExternalMismatchNotice) ...[
              const SizedBox(height: 12),
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

    return TextFormField(
      controller: textController,
      readOnly: readOnly,
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
            '表示カロリーとPFC換算値が異なる場合があります。',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          if (parsed.kcal != null && derivedKcal != null) ...[
            const SizedBox(height: 4),
            Text(
              '表示カロリー：${NutritionValueCalculator.formatForField(MacroField.kcal, parsed.kcal!)} kcal\n'
              'PFC換算：${NutritionValueCalculator.formatForField(MacroField.kcal, derivedKcal)} kcal',
              style: TextStyle(color: color),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '食物繊維・糖アルコール・有機酸・表示丸め等により一致しない場合があります。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
