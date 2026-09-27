import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/exercise_category.dart';
import '../../models/exercise_calculation_source.dart';
import '../../models/exercise_entry.dart';
import '../../models/strength_workout_log.dart';
import '../../widgets/exercise/strength_workout_log_editor.dart';
import '../../services/exercise_calorie_calculator.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/common/logged_at_picker_field.dart';
import '../../widgets/exercise/exercise_met_calculation_section.dart';
import '../../widgets/layout/app_constrained_bottom_bar.dart';
import '../../widgets/layout/app_form_constraint.dart';

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
  late final TextEditingController _notesController;
  StrengthWorkoutLog _strengthLog = const StrengthWorkoutLog(exercises: []);
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
    final parsedNotes = StrengthNotesCodec.parse(entry?.notes);
    _strengthLog =
        parsedNotes.log ??
        entry?.legacyStrengthLog ??
        const StrengthWorkoutLog(exercises: []);
    _notesController = TextEditingController(text: parsedNotes.memo);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _burnedKcalController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isStrength => _metState.category == ExerciseCategory.strength;

  ExerciseEntry? _buildEntry() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }
    if (_metState.activityId == null || _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('種目を選んでください')));
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
    StrengthSetLog? firstSet;
    if (_isStrength) {
      for (final exercise in _strengthLog.exercises) {
        if (exercise.sets.isNotEmpty) {
          firstSet = exercise.sets.first;
          break;
        }
      }
    }
    final notes = StrengthNotesCodec.encode(
      log: _isStrength ? _strengthLog : null,
      memo: _notesController.text,
    );

    return ExerciseEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      name: _nameController.text.trim(),
      durationMin: int.parse(_durationController.text),
      burnedKcal: gross,
      loggedAt: _loggedAt,
      category: _metState.category,
      activityId: _metState.activityId,
      intensity: _metState.intensity,
      sets: _isStrength && _strengthLog.totalSets > 0
          ? _strengthLog.totalSets
          : null,
      reps: firstSet?.reps,
      liftWeightKg: firstSet?.weightKg,
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

    if (!_metState.includeInRemaining ||
        _metState.calculationSource ==
            ExerciseCalculationSource.lifestyleIncluded) {
      return (parsedGross ?? _metState.grossKcal ?? 0, 0);
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
        if (_isStrength)
          StrengthWorkoutLogEditor(
            initialLog: _strengthLog,
            onChanged: (log) => _strengthLog = log,
          ),
        LoggedAtPickerField(
          loggedAt: _loggedAt,
          onChanged: (value) => setState(() => _loggedAt = value),
        ),
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
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                widget.isEditing ? 160 : 100,
              ),
              children: [
                ExerciseMetCalculationSection(
                  controller: widget.controller,
                  loggedAt: _loggedAt,
                  durationController: _durationController,
                  grossKcalController: _burnedKcalController,
                  nameController: _nameController,
                  notesController: _notesController,
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
