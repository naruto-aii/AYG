import 'package:flutter/material.dart';

import '../../models/goal.dart';
import '../../repositories/authentication_repository.dart';
import '../../services/open_food_facts_service.dart';
import '../../state/app_controller.dart';
import '../food/food_form_navigation.dart';
import '../shell/shell_navigation.dart';
import 'activity_level_screen.dart';

class GoalSetupScreen extends StatefulWidget {
  const GoalSetupScreen({
    super.key,
    required this.controller,
    required this.openFoodFactsService,
    required this.authenticationRepository,
    this.mainShellBuilder,
    this.foodFormBuilder,
  });

  final AppController controller;
  final OpenFoodFactsService openFoodFactsService;
  final AuthenticationRepository authenticationRepository;
  final MainShellScreenBuilder? mainShellBuilder;
  final FoodFormScreenBuilder? foodFormBuilder;

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
      final shellBuilder =
          widget.mainShellBuilder ?? defaultMainShellScreenBuilder;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(
          builder: (context) => shellBuilder(
            controller: widget.controller,
            openFoodFactsService: widget.openFoodFactsService,
            authenticationRepository: widget.authenticationRepository,
            foodFormBuilder: widget.foodFormBuilder,
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
          mainShellBuilder: widget.mainShellBuilder,
          foodFormBuilder: widget.foodFormBuilder,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetDateLabel = _targetDate == null
        ? '未選択'
        : '${_targetDate!.year}/${_targetDate!.month}/${_targetDate!.day}';

    return Scaffold(
      appBar: AppBar(title: const Text('目標設定')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                '目標を設定してください',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 24),
              const Text('目標区分'),
              const SizedBox(height: 8),
              SegmentedButton<GoalType>(
                segments: GoalType.values
                    .map(
                      (type) =>
                          ButtonSegment(value: type, label: Text(type.label)),
                    )
                    .toList(),
                selected: {_goalType},
                onSelectionChanged: (selection) {
                  setState(() => _goalType = selection.first);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _targetWeightController,
                decoration: const InputDecoration(
                  labelText: '目標体重 (kg)',
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
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('目標日'),
                subtitle: Text(targetDateLabel),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickTargetDate,
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: _complete, child: const Text('次へ')),
            ],
          ),
        ),
      ),
    );
  }
}
