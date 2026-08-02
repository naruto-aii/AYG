import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/exercise_calculation_source.dart';
import '../../models/exercise_category.dart';
import '../../models/workout_template.dart';
import '../../services/exercise_calorie_calculator.dart';
import '../../services/exercise_weight_resolver.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/logged_at_picker_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/layout/app_form_constraint.dart';
import '../workout_template/workout_template_screens.dart';

Future<void> openWorkoutTemplatePicker({
  required BuildContext context,
  required AppController controller,
}) async {
  final template = await Navigator.of(context).push<WorkoutTemplate>(
    MaterialPageRoute<WorkoutTemplate>(
      builder: (context) => WorkoutTemplatePickerScreen(controller: controller),
    ),
  );
  if (template == null || !context.mounted) {
    return;
  }

  final bundle = await controller.getWorkoutTemplateWithItems(
    template.templateId,
  );
  if (bundle == null || !context.mounted) {
    return;
  }

  await Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => WorkoutTemplateApplyScreen(
        controller: controller,
        template: bundle.template,
        items: bundle.items,
      ),
    ),
  );
}

Future<void> openWorkoutTemplateCreate(
  BuildContext context,
  AppController controller,
) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (context) => WorkoutTemplateFormScreen(controller: controller),
    ),
  );
}

Future<void> saveCurrentExerciseAsTemplate({
  required BuildContext context,
  required AppController controller,
  required WorkoutTemplateItem itemDraft,
}) async {
  final nameController = TextEditingController();
  final saved = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('テンプレートとして保存'),
      content: TextField(
        controller: nameController,
        decoration: const InputDecoration(labelText: 'テンプレート名'),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('キャンセル'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('保存'),
        ),
      ],
    ),
  );

  if (saved != true || !context.mounted) {
    nameController.dispose();
    return;
  }

  final name = nameController.text.trim();
  nameController.dispose();
  if (name.isEmpty) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('テンプレート名を入力してください')));
    return;
  }

  try {
    await controller.saveWorkoutTemplate(
      draft: WorkoutTemplateDraft(name: name, items: [itemDraft]),
    );
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('テンプレートを保存しました')));
  } catch (error) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $error')));
  }
}

class WorkoutTemplateApplyScreen extends StatefulWidget {
  const WorkoutTemplateApplyScreen({
    super.key,
    required this.controller,
    required this.template,
    required this.items,
  });

  final AppController controller;
  final WorkoutTemplate template;
  final List<WorkoutTemplateItem> items;

  @override
  State<WorkoutTemplateApplyScreen> createState() =>
      _WorkoutTemplateApplyScreenState();
}

class _WorkoutTemplateApplyScreenState
    extends State<WorkoutTemplateApplyScreen> {
  static const _calculator = ExerciseCalorieCalculator();
  static const _weightResolver = ExerciseWeightResolver();

  late List<WorkoutTemplateApplyDraft> _drafts;
  late DateTime _loggedAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loggedAt = DateTime.now();
    _drafts = widget.items
        .map(
          (item) => WorkoutTemplateApplyDraft(
            name: item.name,
            durationMin: item.durationMin,
            loggedAt: _loggedAt,
            intensity: item.intensity,
            sets: item.sets,
            reps: item.reps,
            liftWeightKg: item.liftWeightKg,
            metValue: item.metValue,
            notes: item.notes,
            activityId: item.activityId,
            categoryKey: item.categoryKey,
            sourceKey: item.sourceKey,
          ),
        )
        .toList();
    _recalculateAll();
  }

  void _recalculateAll() {
    final weight = _weightResolver.resolve(
      exerciseLoggedAt: _loggedAt,
      weightEntries: widget.controller.weightEntries,
      profile: widget.controller.profile,
    );
    if (weight == null) {
      return;
    }

    setState(() {
      _drafts = _drafts.map((draft) {
        final activity = MetActivityCatalog.findById(draft.activityId);
        final met =
            activity?.intensityById(draft.intensity)?.met ??
            draft.metValue ??
            activity?.defaultMet ??
            3.0;
        final estimate = _calculator.estimate(
          met: met,
          weightKg: weight.weightKg,
          durationMinutes: draft.durationMin,
          source: ExerciseCalculationSource.template,
          sourceKey: draft.sourceKey,
        );
        if (estimate == null) {
          return draft;
        }
        return WorkoutTemplateApplyDraft(
          name: draft.name,
          durationMin: draft.durationMin,
          loggedAt: _loggedAt,
          intensity: draft.intensity,
          sets: draft.sets,
          reps: draft.reps,
          liftWeightKg: draft.liftWeightKg,
          metValue: estimate.met,
          grossKcal: estimate.grossKcal,
          netKcal: estimate.netKcal,
          notes: draft.notes,
          activityId: draft.activityId,
          categoryKey: draft.categoryKey,
          sourceKey: estimate.sourceKey,
        );
      }).toList();
    });
  }

  Future<void> _register() async {
    setState(() => _isSaving = true);
    await widget.controller.registerWorkoutEntriesFromDrafts(_drafts);
    if (!mounted) {
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.template.name)),
      body: SafeArea(
        child: AppFormConstraint(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              LoggedAtPickerField(
                loggedAt: _loggedAt,
                onChanged: (value) {
                  setState(() => _loggedAt = value);
                  _recalculateAll();
                },
              ),
              const SizedBox(height: AppSpacing.md),
              for (final draft in _drafts)
                AppCard(
                  child: ListTile(
                    title: Text(draft.name),
                    subtitle: Text(
                      '${draft.durationMin}分 · '
                      'net ${draft.netKcal?.toStringAsFixed(0) ?? '-'} kcal',
                    ),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                onPressed: _isSaving ? null : _register,
                label: _isSaving ? '登録中…' : '一括登録',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
