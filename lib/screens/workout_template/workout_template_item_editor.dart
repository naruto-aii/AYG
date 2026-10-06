import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/exercise_quantity_unit.dart';
import '../../models/workout_template.dart';
import '../../services/exercise_calorie_calculator.dart';
import '../../state/app_controller.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_spacing.dart';
import '../../utils/id_generator.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/icon_circle.dart';
import '../../widgets/exercise/exercise_met_calculation_section.dart';

/// 運動テンプレートの種目。通常の運動登録と同じ計算欄を使う。
class WorkoutTemplateItemEditor extends StatefulWidget {
  const WorkoutTemplateItemEditor({
    super.key,
    required this.controller,
    required this.sortOrder,
  });

  final AppController controller;
  final int sortOrder;

  @override
  State<WorkoutTemplateItemEditor> createState() =>
      _WorkoutTemplateItemEditorState();
}

class _WorkoutTemplateItemEditorState extends State<WorkoutTemplateItemEditor> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _distanceController = TextEditingController();
  final _repsController = TextEditingController();
  final _grossController = TextEditingController();
  final _notesController = TextEditingController();
  final _setsController = TextEditingController();
  final _liftWeightController = TextEditingController();
  ExerciseMetFormState _metState = ExerciseMetFormState();

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _repsController.dispose();
    _grossController.dispose();
    _notesController.dispose();
    _setsController.dispose();
    _liftWeightController.dispose();
    super.dispose();
  }

  bool get _showsLoadFields {
    final unit = MetActivityCatalog.findById(
      _metState.activityId,
    )?.quantityUnit;
    return unit == ExerciseQuantityUnit.reps;
  }

  int? _parseOptionalInt(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  double? _parseOptionalDouble(TextEditingController controller) {
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    return double.tryParse(raw);
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    final activity = MetActivityCatalog.findById(_metState.activityId);
    final name = _nameController.text.trim();
    if (activity == null || name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('種目を選んでください')));
      return;
    }

    final unit = activity.quantityUnit;
    final durationMin = switch (unit) {
      ExerciseQuantityUnit.distanceKm =>
        ExerciseCalorieCalculator.companionDurationMin(
          distanceKm: _parseOptionalDouble(_distanceController) ?? 0,
          referenceSpeedKmh: activity.speedFor(_metState.intensity),
        ),
      ExerciseQuantityUnit.reps =>
        activity.requiresManualKcal
            ? 1
            : ExerciseCalorieCalculator.durationMinForReps(
                _parseOptionalInt(_repsController) ?? 0,
              ),
      ExerciseQuantityUnit.durationMin =>
        int.tryParse(_durationController.text.trim()) ?? 0,
    };
    if (durationMin <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('時間か量を入力してください')));
      return;
    }

    Navigator.of(context).pop(
      WorkoutTemplateItem(
        itemId: generateUniqueId(),
        name: name,
        activityId: activity.id,
        categoryKey: activity.category.name,
        intensity: _metState.intensity,
        durationMin: durationMin,
        sets: _showsLoadFields ? _parseOptionalInt(_setsController) : null,
        reps: unit == ExerciseQuantityUnit.reps
            ? _parseOptionalInt(_repsController)
            : null,
        liftWeightKg: _showsLoadFields
            ? _parseOptionalDouble(_liftWeightController)
            : null,
        sortOrder: widget.sortOrder,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        metValue: activity.netKcalPerKgKm != null ? null : _metState.metValue,
        sourceKey: _metState.sourceKey ?? activity.sourceKey,
      ),
    );
  }

  Widget _icon(String asset) => AppIcon(
    asset,
    size: 24,
    color: IconCircle.foregroundOf(IconCircleTone.green),
  );

  Widget _numberField({
    required Key fieldKey,
    required String label,
    required String suffix,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return DesignFieldCard(
      icon: _icon(AppIcons.dumbbell),
      label: label,
      child: DesignInputBox(
        suffix: suffix,
        child: DesignTextInput(
          key: fieldKey,
          controller: controller,
          keyboardType: keyboardType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bottomBar: DesignButton(
        label: 'この種目を追加',
        showTrailingIcon: false,
        onPressed: _submit,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DesignTitleBlock(
              title: '種目を追加',
              subtitle: '種目、時間、きつさから消費カロリーを計算します。',
            ),
            ExerciseMetCalculationSection(
              controller: widget.controller,
              loggedAt: DateTime.now(),
              durationController: _durationController,
              distanceController: _distanceController,
              repsController: _repsController,
              grossKcalController: _grossController,
              nameController: _nameController,
              notesController: _notesController,
              isEditing: false,
              additionalFields: _showsLoadFields
                  ? Column(
                      children: [
                        _numberField(
                          fieldKey: const Key('template-exercise-sets'),
                          label: 'セット',
                          suffix: 'セット',
                          controller: _setsController,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _numberField(
                          fieldKey: const Key('template-exercise-weight'),
                          label: '重量（kg）',
                          suffix: 'kg',
                          controller: _liftWeightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ],
                    )
                  : null,
              onEstimateChanged: (state) => setState(() => _metState = state),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
