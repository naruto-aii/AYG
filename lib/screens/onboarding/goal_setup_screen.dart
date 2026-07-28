import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/goal.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/onboarding/onboarding_scaffold.dart';
import '../shell/main_shell_screen.dart';
import 'activity_level_screen.dart';

class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;

  @override
  State<GoalSetupScreen> createState() => _GoalSetupScreenState();
}

class _GoalSetupScreenState extends State<GoalSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  GoalType _goalType = GoalType.maintain;
  final _targetWeightController = TextEditingController();
  DateTime? _targetDate;

  @override
  void dispose() {
    _targetWeightController.dispose();
    super.dispose();
  }

  Future<void> _pickTargetDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _complete() {
    if (_targetDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目標日を選択してください')));
      return;
    }

    if (_formKey.currentState?.validate() != true) {
      return;
    }

    widget.controller.setGoal(
      Goal(
        type: _goalType,
        targetWeightKg: double.parse(_targetWeightController.text),
        targetDate: _targetDate!,
      ),
    );

    if (widget.controller.useHealthIntegration) {
      widget.controller.completeOnboarding();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (context) => MainShellScreen(
            controller: widget.controller,
            openFoodFactsService: widget.openFoodFactsService,
            authenticationRepository: widget.authenticationRepository,
          ),
        ),
        (route) => false,
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => ActivityLevelScreen(
          controller: widget.controller,
          openFoodFactsService: widget.openFoodFactsService,
          authenticationRepository: widget.authenticationRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetDateLabel = _targetDate == null
        ? AppStrings.notSelected
        : '${_targetDate!.year}/${_targetDate!.month}/${_targetDate!.day}';

    return Form(
      key: _formKey,
      child: OnboardingScaffold(
        title: AppStrings.settingsGoal,
        subtitle: '目標を設定してください',
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(AppStrings.goalType),
            const SizedBox(height: AppSpacing.sm),
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
            AppTextField(
              controller: _targetWeightController,
              label: AppStrings.targetWeightKg,
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
              title: Text(AppStrings.targetDate),
              subtitle: Text(targetDateLabel),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickTargetDate,
            ),
          ],
        ),
        action: PrimaryButton(label: AppStrings.next, onPressed: _complete),
      ),
    );
  }
}
