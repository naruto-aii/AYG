import 'package:flutter/material.dart';

import '../../models/calculation/calorie_target_mode.dart';
import '../../models/macro_field.dart';
import '../../services/goal_macro_input.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../design/design_field.dart';
import '../design/design_segment.dart';

/// 自動計算と手入力の切り替え。数字欄は常に出す。単位は kcal と g/日。
class CalorieTargetEditor extends StatefulWidget {
  const CalorieTargetEditor({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.kcalController,
    required this.proteinController,
    required this.fatController,
    required this.carbController,
    this.onEdited,
  });

  final CalorieTargetMode mode;
  final ValueChanged<CalorieTargetMode> onModeChanged;
  final TextEditingController kcalController;
  final TextEditingController proteinController;
  final TextEditingController fatController;
  final TextEditingController carbController;

  /// 数字を書き換えたとき。目標設定では、これで手入力に切り替える。
  final VoidCallback? onEdited;

  @override
  State<CalorieTargetEditor> createState() => _CalorieTargetEditorState();
}

class _CalorieTargetEditorState extends State<CalorieTargetEditor> {
  final _input = GoalMacroInput();

  @override
  void didUpdateWidget(CalorieTargetEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mode == CalorieTargetMode.automatic &&
        oldWidget.mode != CalorieTargetMode.automatic) {
      _input.reset();
    }
  }

  void _onChanged(MacroField field) {
    final revealed = _input.onUserEdit(
      edited: field,
      kcal: widget.kcalController,
      protein: widget.proteinController,
      fat: widget.fatController,
      carb: widget.carbController,
    );
    widget.onEdited?.call();
    setState(() {});
    final controller = revealed == null || revealed == field
        ? null
        : _controllerFor(revealed);
    final revealedText = controller?.text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (controller != null &&
          revealedText != null &&
          controller.text == revealedText) {
        // 別欄の onChanged 中に入れた文字は、その場の setState では描画されない。
        controller.value = TextEditingValue(
          text: revealedText.isEmpty ? ' ' : revealedText,
          selection: const TextSelection.collapsed(offset: 0),
        );
        controller.value = TextEditingValue(
          text: revealedText,
          selection: TextSelection.collapsed(offset: revealedText.length),
        );
      }
      setState(() {});
    });
  }

  TextEditingController _controllerFor(MacroField field) {
    return switch (field) {
      MacroField.kcal => widget.kcalController,
      MacroField.protein => widget.proteinController,
      MacroField.fat => widget.fatController,
      MacroField.carb => widget.carbController,
    };
  }

  @override
  Widget build(BuildContext context) {
    final manual = widget.mode == CalorieTargetMode.manual;
    final message = manual ? _input.message : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('1日の食事目標', style: AppTypography.titleS),
        const SizedBox(height: 8),
        DesignSegmentGroup<CalorieTargetMode>(
          values: CalorieTargetMode.values,
          labelOf: (mode) => mode.labelJa,
          selected: widget.mode,
          onChanged: widget.onModeChanged,
        ),
        const SizedBox(height: 8),
        Text(
          manual
              ? 'カロリーとPFCのうち2つを入れると、残り1つを計算します。この数字は体重や残日数では変わりません。'
              : '数字を書き換えると自分で入力になります。自動で計算に戻すと、体重と残日数の式に戻ります。',
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        _numberField(
          field: MacroField.kcal,
          label: 'カロリー',
          suffix: 'kcal',
          hintText: '1800',
          controller: widget.kcalController,
          inputKey: const Key('goal-target-kcal'),
        ),
        const SizedBox(height: 10),
        _numberField(
          field: MacroField.protein,
          label: 'たんぱく質',
          suffix: 'g/日',
          hintText: '120',
          controller: widget.proteinController,
          inputKey: const Key('goal-target-protein'),
        ),
        const SizedBox(height: 10),
        _numberField(
          field: MacroField.fat,
          label: '脂質',
          suffix: 'g/日',
          hintText: '50',
          controller: widget.fatController,
          inputKey: const Key('goal-target-fat'),
        ),
        const SizedBox(height: 10),
        _numberField(
          field: MacroField.carb,
          label: '炭水化物',
          suffix: 'g/日',
          hintText: '200',
          controller: widget.carbController,
          inputKey: const Key('goal-target-carb'),
        ),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(
            message,
            style: AppTypography.caption.copyWith(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  Widget _numberField({
    required MacroField field,
    required String label,
    required String suffix,
    required String hintText,
    required TextEditingController controller,
    required Key inputKey,
  }) {
    return DesignFieldCard(
      icon: const SizedBox.shrink(),
      label: label,
      child: DesignInputBox(
        suffix: suffix,
        child: DesignTextInput(
          controller: controller,
          hintText: hintText,
          inputKey: inputKey,
          onChanged: (_) => _onChanged(field),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
    );
  }
}

/// 手入力の4項目。足りなければ、またはカロリーとPFCが合わなければメッセージを返す。
String? validateManualCalorieTargets({
  required String kcalText,
  required String proteinText,
  required String fatText,
  required String carbText,
}) {
  final mismatch = goalMacroSaveMessage(
    kcalText: kcalText,
    proteinText: proteinText,
    fatText: fatText,
    carbText: carbText,
  );
  if (mismatch != null) {
    return mismatch;
  }
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
