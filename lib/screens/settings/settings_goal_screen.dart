import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/calculation/goal_pace.dart';
import '../../models/goal.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/design_segment.dart';
import '../../widgets/design/goal_card.dart';
import '../../widgets/design/icon_circle.dart';
import '../../utils/goal_validation_warnings.dart';

class SettingsGoalScreen extends StatefulWidget {
  const SettingsGoalScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsGoalScreen> createState() => _SettingsGoalScreenState();
}

class _SettingsGoalScreenState extends State<SettingsGoalScreen> {
  late GoalType _goalType;
  late GoalPace _goalPace;
  final _targetWeightController = TextEditingController();
  late DateTime _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.controller.goal!;
    _goalType = goal.type;
    _goalPace = goal.goalPace;
    _targetWeightController.text = goal.targetWeightKg.toStringAsFixed(1);
    _targetDate = goal.targetDate;
  }

  @override
  void dispose() {
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  Future<void> _save() async {
    final targetWeightKg = double.tryParse(_targetWeightController.text.trim());
    if (targetWeightKg == null || targetWeightKg < 30 || targetWeightKg > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目標体重は 30〜300 kg の範囲で入力してください')),
      );
      return;
    }
    final currentWeightKg =
        widget.controller.profile?.weightKg ?? targetWeightKg;
    final warnings = collectGoalWarnings(
      goalType: _goalType,
      targetWeightKg: targetWeightKg,
      currentWeightKg: currentWeightKg,
      targetDate: _targetDate,
    );

    if (warnings.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(AppStrings.goalWarningTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: warnings.map((warning) => Text('• $warning')).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(AppStrings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(AppStrings.save),
            ),
          ],
        ),
      );
      if (proceed != true) {
        return;
      }
    }

    setState(() => _isSaving = true);
    await widget.controller.saveGoalSettings(
      Goal(
        type: _goalType,
        targetWeightKg: targetWeightKg,
        targetDate: _targetDate,
        goalPace: _goalType == GoalType.maintain
            ? GoalPace.standard
            : _goalPace,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('保存しました')));
    Navigator.of(context).pop();
  }

  Widget _goalIcon(String asset, GoalType type) => AppIcon(
    asset,
    size: 32,
    color: _goalType == type ? AppColors.iconPrimary : AppColors.textSecondary,
  );

  Widget _fieldIcon(String asset) => AppIcon(
    asset,
    size: 24,
    color: IconCircle.foregroundOf(IconCircleTone.green),
  );

  void _selectType(GoalType type) {
    setState(() {
      _goalType = type;
      if (type == GoalType.maintain) {
        _goalPace = GoalPace.standard;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final showPace =
        _goalType == GoalType.lose || _goalType == GoalType.gain;

    return DesignPage(
      bottomBar: DesignButton(
        label: AppStrings.save,
        showTrailingIcon: false,
        loading: _isSaving,
        onPressed: _isSaving ? null : _save,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: '目標',
            subtitle: '目標体重と期限を変えると、1日の目標も変わります。',
          ),
          Text('目標の方向性', style: AppTypography.titleS),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GoalCard(
                  icon: _goalIcon(AppIcons.scale, GoalType.lose),
                  title: GoalType.lose.label,
                  description: '体重を減らしたい',
                  selected: _goalType == GoalType.lose,
                  onTap: () => _selectType(GoalType.lose),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GoalCard(
                  icon: _goalIcon(AppIcons.human, GoalType.maintain),
                  title: GoalType.maintain.label,
                  description: '今の体重を\nキープしたい',
                  selected: _goalType == GoalType.maintain,
                  onTap: () => _selectType(GoalType.maintain),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GoalCard(
                  icon: _goalIcon(AppIcons.dumbbell, GoalType.gain),
                  title: GoalType.gain.label,
                  description: '体重を増やしたい',
                  selected: _goalType == GoalType.gain,
                  onTap: () => _selectType(GoalType.gain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DesignFieldCard(
            icon: _fieldIcon(AppIcons.scale),
            label: AppStrings.targetWeightKg,
            child: DesignInputBox(
              suffix: 'kg',
              child: DesignTextInput(
                controller: _targetWeightController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: _fieldIcon(AppIcons.calendar),
            label: AppStrings.targetDate,
            child: DesignInputBox(
              onTap: _pickTargetDate,
              child: Text(
                '${_targetDate.year}年${_targetDate.month}月${_targetDate.day}日',
                style: AppTypography.bodyL.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (showPace) ...[
            const SizedBox(height: 18),
            Text(
              _goalType == GoalType.lose ? '減量ペース' : '増量ペース',
              style: AppTypography.titleS,
            ),
            const SizedBox(height: 10),
            DesignSegmentGroup<GoalPace>(
              values: GoalPace.values,
              labelOf: (pace) => pace.labelJa,
              selected: _goalPace,
              onChanged: (pace) => setState(() => _goalPace = pace),
            ),
            const SizedBox(height: 8),
            Text(
              '${_goalPace.descriptionJa}\nペースの係数や kcal/kg の詳細は「計算根拠」で確認できます。',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
