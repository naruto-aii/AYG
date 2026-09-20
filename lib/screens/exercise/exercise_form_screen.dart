import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/exercise_category.dart';
import '../../models/exercise_calculation_source.dart';
import '../../models/exercise_entry.dart';
import '../../models/workout_template.dart';
import '../../services/exercise_calorie_calculator.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/common/logged_at_picker_field.dart';
import '../../widgets/exercise/exercise_met_calculation_section.dart';
import '../../widgets/layout/app_constrained_bottom_bar.dart';
import '../../widgets/layout/app_form_constraint.dart';
import 'exercise_form_template_actions.dart';

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({
    super.key,
    required this.controller,
    this.entry,
    this.initialLoggedAt,
  });

  final AppController controller;
  final ExerciseEntry? entry;
  final DateTime? initialLoggedAt;

  bool get isEditing => entry != null;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _burnedKcalController;
  late final TextEditingController _setsController;
  late final TextEditingController _repsController;
  late final TextEditingController _liftWeightController;
  late final TextEditingController _notesController;
  late DateTime _loggedAt;
  bool _isSaving = false;
  ExerciseMetFormState _metState = ExerciseMetFormState();

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _loggedAt = (entry?.loggedAt ?? widget.initialLoggedAt ?? DateTime.now())
        .toLocal();
    _nameController = TextEditingController(text: entry?.name ?? '');
    _durationController = TextEditingController(
      text: entry?.durationMin.toString() ?? '',
    );
    _burnedKcalController = TextEditingController(
      text: entry != null ? entry.effectiveGrossKcal.toString() : '',
    );
    _setsController = TextEditingController(
      text: entry?.sets?.toString() ?? '',
    );
    _repsController = TextEditingController(
      text: entry?.reps?.toString() ?? '',
    );
    _liftWeightController = TextEditingController(
      text: entry?.liftWeightKg?.toString() ?? '',
    );
    _notesController = TextEditingController(text: entry?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _burnedKcalController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _liftWeightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isStrength => _metState.category == ExerciseCategory.strength;

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

  ExerciseEntry? _buildEntry() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }

    final grossAndNet = _resolveGrossAndNetKcal();
    if (grossAndNet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('消費カロリーを計算できないか、詳細設定で追加消費を入力してください')),
      );
      return null;
    }
    final gross = grossAndNet.$1;
    final net = grossAndNet.$2;
    final notes = _notesController.text.trim();

    return ExerciseEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      name: _nameController.text.trim(),
      durationMin: int.parse(_durationController.text),
      burnedKcal: gross,
      loggedAt: _loggedAt,
      category: _metState.category,
      activityId: _metState.activityId,
      intensity: _metState.intensity,
      sets: _isStrength ? _parseOptionalInt(_setsController) : null,
      reps: _isStrength ? _parseOptionalInt(_repsController) : null,
      liftWeightKg: _isStrength
          ? _parseOptionalDouble(_liftWeightController)
          : null,
      metValue: _metState.metValue,
      grossKcal: gross,
      netKcal: net,
      weightKgSnapshot: _metState.weightKgSnapshot,
      calculationSource: _metState.calculationSource,
      calculationVersion:
          _metState.calculationVersion ?? MetActivityCatalog.calculationVersion,
      sourceKey: _metState.sourceKey,
      notes: notes.isEmpty ? null : notes,
    );
  }

  /// 保存直前に MET 入力から gross/net を再計算（編集時の古い値混在を防ぐ）。
  (double, double)? _resolveGrossAndNetKcal() {
    final parsedGross = double.tryParse(_burnedKcalController.text.trim());

    if (_metState.manualOverride ||
        _metState.calculationSource ==
            ExerciseCalculationSource.manualOverride) {
      final net = _metState.netKcal ?? parsedGross;
      if (net == null) {
        return null;
      }
      return (parsedGross ?? _metState.grossKcal ?? net, net);
    }

    final duration = int.tryParse(_durationController.text.trim());
    final met = _metState.metValue;
    final weight =
        _metState.weightKgSnapshot ?? widget.controller.profile?.weightKg;
    if (duration != null &&
        duration > 0 &&
        met != null &&
        met > 0 &&
        weight != null &&
        weight > 0) {
      const calculator = ExerciseCalorieCalculator();
      final estimate = calculator.estimate(
        met: met,
        weightKg: weight,
        durationMinutes: duration,
        sourceKey: _metState.sourceKey,
      );
      if (estimate != null) {
        return (estimate.grossKcal, estimate.netKcal);
      }
    }

    if (parsedGross != null) {
      return (parsedGross, _metState.netKcal ?? parsedGross);
    }
    if (_metState.grossKcal != null && _metState.netKcal != null) {
      return (_metState.grossKcal!, _metState.netKcal!);
    }
    return null;
  }

  Future<void> _save() async {
    final entry = _buildEntry();
    if (entry == null) {
      return;
    }

    setState(() => _isSaving = true);
    if (widget.isEditing) {
      await widget.controller.updateExercise(entry);
    } else {
      await widget.controller.addExercise(entry);
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final entry = widget.entry;
    if (entry == null) {
      return;
    }

    await confirmDeleteWithUndo<ExerciseEntry>(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
      snapshot: entry,
      onDelete: () => widget.controller.deleteExercise(entry.id),
      onRestore: (restored) => widget.controller.restoreExerciseEntry(restored),
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Widget _buildAdditionalFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isStrength) ...[
          AppTextField(
            controller: _setsController,
            label: 'セット',
            keyboardType: TextInputType.number,
          ),
          AppTextField(
            controller: _repsController,
            label: '回数',
            keyboardType: TextInputType.number,
          ),
          AppTextField(
            controller: _liftWeightController,
            label: '重量（kg）',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        LoggedAtPickerField(
          loggedAt: _loggedAt,
          onChanged: (value) => setState(() => _loggedAt = value),
        ),
        AppTextField(controller: _notesController, label: 'メモ', maxLines: 3),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '運動を編集' : '運動を追加')),
      body: SafeArea(
        child: AppFormConstraint(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                widget.isEditing ? 160 : 120,
              ),
              children: [
                ExerciseMetCalculationSection(
                  controller: widget.controller,
                  loggedAt: _loggedAt,
                  durationController: _durationController,
                  grossKcalController: _burnedKcalController,
                  nameController: _nameController,
                  additionalFields: _buildAdditionalFields(),
                  isEditing: widget.isEditing,
                  initialEntry: widget.entry,
                  onEstimateChanged: (state) =>
                      setState(() => _metState = state),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: AppConstrainedBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PrimaryButton(
              label: '保存',
              loading: _isSaving,
              onPressed: _isSaving ? null : _save,
            ),
            if (!widget.isEditing) ...[
              const SizedBox(height: AppSpacing.xs),
              SecondaryButton(
                label: '入力内容をテンプレートとして保存',
                onPressed: () {
                  final duration = int.tryParse(
                    _durationController.text.trim(),
                  );
                  final name = _nameController.text.trim();
                  if (name.isEmpty || duration == null || duration <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('表示名と実施時間を入力してください')),
                    );
                    return;
                  }
                  saveCurrentExerciseAsTemplate(
                    context: context,
                    controller: widget.controller,
                    itemDraft: WorkoutTemplateItem(
                      itemId: widget.controller.generateId(),
                      name: name,
                      durationMin: duration,
                      categoryKey: _metState.category?.id,
                      activityId: _metState.activityId,
                      intensity: _metState.intensity,
                      metValue: _metState.metValue,
                      sourceKey: _metState.sourceKey,
                      sets: _isStrength
                          ? _parseOptionalInt(_setsController)
                          : null,
                      reps: _isStrength
                          ? _parseOptionalInt(_repsController)
                          : null,
                      liftWeightKg: _isStrength
                          ? _parseOptionalDouble(_liftWeightController)
                          : null,
                      notes: _notesController.text.trim().isEmpty
                          ? null
                          : _notesController.text.trim(),
                      sortOrder: 1,
                    ),
                  );
                },
              ),
            ],
            if (widget.isEditing) ...[
              const SizedBox(height: AppSpacing.xs),
              SecondaryButton(label: '削除', onPressed: _confirmDelete),
            ],
          ],
        ),
      ),
    );
  }
}
