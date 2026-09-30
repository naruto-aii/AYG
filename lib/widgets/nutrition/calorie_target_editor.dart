import 'package:flutter/material.dart';

import '../../models/calculation/calorie_target_mode.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../design/design_field.dart';
import '../design/design_segment.dart';

/// 自動計算と手入力の切り替え。単位は kcal と g/日。
class CalorieTargetEditor extends StatelessWidget {
  const CalorieTargetEditor({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.kcalController,
    required this.proteinController,
    required this.fatController,
    required this.carbController,
  });

  final CalorieTargetMode mode;
  final ValueChanged<CalorieTargetMode> onModeChanged;
  final TextEditingController kcalController;
  final TextEditingController proteinController;
  final TextEditingController fatController;
  final TextEditingController carbController;

  @override
  Widget build(BuildContext context) {
    final manual = mode == CalorieTargetMode.manual;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('食事の目標', style: AppTypography.titleS),
        const SizedBox(height: 8),
        DesignSegmentGroup<CalorieTargetMode>(
          values: CalorieTargetMode.values,
          labelOf: (mode) => mode.labelJa,
          selected: mode,
          onChanged: onModeChanged,
        ),
        const SizedBox(height: 8),
        Text(
          manual
              ? '手入力のあいだは、体重や残日数ではこの数字を変えません。'
              : '自動は、目標日と目標体重から毎日計算します。目標日と目標体重そのものは変えません。',
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
        if (manual) ...[
          const SizedBox(height: 10),
          _numberField(
            label: 'カロリー',
            suffix: 'kcal',
            controller: kcalController,
          ),
          const SizedBox(height: 10),
          _numberField(
            label: 'たんぱく質',
            suffix: 'g/日',
            controller: proteinController,
          ),
          const SizedBox(height: 10),
          _numberField(label: '脂質', suffix: 'g/日', controller: fatController),
          const SizedBox(height: 10),
          _numberField(
            label: '炭水化物',
            suffix: 'g/日',
            controller: carbController,
          ),
        ],
      ],
    );
  }

  Widget _numberField({
    required String label,
    required String suffix,
    required TextEditingController controller,
  }) {
    return DesignFieldCard(
      icon: const SizedBox.shrink(),
      label: label,
      child: DesignInputBox(
        suffix: suffix,
        child: DesignTextInput(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
    );
  }
}

/// 手入力の4項目。足りなければメッセージを返す。
String? validateManualCalorieTargets({
  required String kcalText,
  required String proteinText,
  required String fatText,
  required String carbText,
}) {
  final kcal = double.tryParse(kcalText.trim());
  final protein = double.tryParse(proteinText.trim());
  final fat = double.tryParse(fatText.trim());
  final carb = double.tryParse(carbText.trim());
  if (kcal == null || kcal < 500 || kcal > 10000) {
    return 'カロリーは 500〜10000 kcal で入力してください';
  }
  if (protein == null || protein < 0 || protein > 500) {
    return 'たんぱく質は 0〜500 g/日 で入力してください';
  }
  if (fat == null || fat < 0 || fat > 500) {
    return '脂質は 0〜500 g/日 で入力してください';
  }
  if (carb == null || carb < 0 || carb > 1500) {
    return '炭水化物は 0〜1500 g/日 で入力してください';
  }
  return null;
}
