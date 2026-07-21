import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/goal.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/goal_validation_warnings.dart';

class SettingsGoalScreen extends StatefulWidget {
  const SettingsGoalScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsGoalScreen> createState() => _SettingsGoalScreenState();
}

class _SettingsGoalScreenState extends State<SettingsGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  late GoalType _goalType;
  final _targetWeightController = TextEditingController();
  late DateTime _targetDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final goal = widget.controller.goal!;
    _goalType = goal.type;
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
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    final targetWeightKg = double.parse(_targetWeightController.text);
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

  @override
  Widget build(BuildContext context) {
    final targetDateLabel =
        '${_targetDate.year}/${_targetDate.month}/${_targetDate.day}';

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settingsGoal)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              const Text(AppStrings.goalType),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<GoalType>(
                segments: GoalType.values
                    .map(
                      (type) => ButtonSegment(
                        value: type,
                        label: Text(AppStrings.goalTypeLabel(type)),
                      ),
                    )
                    .toList(),
                selected: {_goalType},
                onSelectionChanged: (selection) {
                  setState(() => _goalType = selection.first);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _targetWeightController,
                decoration: const InputDecoration(
                  labelText: AppStrings.targetWeightKg,
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '目標体重を入力してください';
                  }
                  final parsed = double.tryParse(value);
                  if (parsed == null || parsed < 30 || parsed > 300) {
                    return '30〜300 kg の範囲で入力してください';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.targetDate),
                subtitle: Text(targetDateLabel),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickTargetDate,
              ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(AppStrings.save),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
