import 'package:flutter/material.dart';

import '../../models/macro_field.dart';
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
