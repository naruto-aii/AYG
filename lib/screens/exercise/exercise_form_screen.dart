import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/exercise_category.dart';
import '../../models/exercise_calculation_source.dart';
import '../../models/exercise_entry.dart';
import '../../models/exercise_quantity_unit.dart';
import '../../services/exercise_calorie_calculator.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/food_search_normalizer.dart';
import '../../widgets/common/delete_with_undo.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/icon_circle.dart';
import '../../widgets/exercise/exercise_met_calculation_section.dart';

Future<bool?> showSaveCustomActivityTemplateDialog({
  required BuildContext context,
  required String activityName,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: DesignCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'テンプレートに追加',
                style: AppTypography.titleM.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                '「$activityName」をテンプレートに追加しますか？次回から一覧で選べます。',
                style: AppTypography.bodyL.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DesignButton(
                label: 'はい',
                showTrailingIcon: false,
                onPressed: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: AppSpacing.md),
              DesignButton(
                label: 'いいえ',
                style: DesignButtonStyle.outline,
                showTrailingIcon: false,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class ExerciseFormScreen extends StatefulWidget {
  static const setsFieldKey = Key('exercise-sets');
  static const repsFieldKey = Key('exercise-reps');
  static const liftWeightFieldKey = Key('exercise-lift-weight');

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
  late final TextEditingController _distanceController;
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
    _distanceController = TextEditingController(
      text: entry?.distanceKm?.toString() ?? '',
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
    _distanceController.dispose();
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
    final notes = _notesController.text.trim();

    final activity = MetActivityCatalog.findById(_metState.activityId);
    final unit = activity?.quantityUnit ?? ExerciseQuantityUnit.durationMin;
    final distanceKm = unit == ExerciseQuantityUnit.distanceKm
        ? _parseOptionalDouble(_distanceController)
        : null;
    final reps = unit == ExerciseQuantityUnit.reps
        ? _parseOptionalInt(_repsController)
        : null;
    final durationMin = switch (unit) {
      ExerciseQuantityUnit.distanceKm =>
        ExerciseCalorieCalculator.companionDurationMin(
          distanceKm: distanceKm ?? 0,
          referenceSpeedKmh: activity?.referenceSpeedKmh,
        ),
      ExerciseQuantityUnit.reps => ExerciseCalorieCalculator.durationMinForReps(
        reps ?? 0,
      ),
      ExerciseQuantityUnit.durationMin => int.parse(_durationController.text),
    };

    return ExerciseEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      name: _nameController.text.trim(),
      durationMin: durationMin,
      burnedKcal: gross,
      loggedAt: _loggedAt,
      category: _metState.category,
      activityId: _metState.activityId,
      intensity: _metState.intensity,
      sets: _isStrength ? _parseOptionalInt(_setsController) : null,
      reps: reps,
      liftWeightKg: _isStrength
          ? _parseOptionalDouble(_liftWeightController)
          : null,
      distanceKm: distanceKm,
      metValue: activity?.netKcalPerKgKm != null ? null : _metState.metValue,
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
    final activity = MetActivityCatalog.findById(_metState.activityId);
    if (activity != null && !activity.caloriesFromFormula) {
      final net = _metState.netKcal ?? parsedGross;
      if (net == null) {
        return (0, 0);
      }
      return (parsedGross ?? _metState.grossKcal ?? net, net);
    }

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

    final weight =
        _metState.weightKgSnapshot ?? widget.controller.profile?.weightKg;
    if (activity != null && weight != null && weight > 0) {
      const calculator = ExerciseCalorieCalculator();
      final estimate = switch (activity.quantityUnit) {
        ExerciseQuantityUnit.distanceKm => _distanceEstimate(
          calculator,
          activity,
          weight,
        ),
        ExerciseQuantityUnit.reps => _repsEstimate(
          calculator,
          activity,
          weight,
        ),
        ExerciseQuantityUnit.durationMin => _durationEstimate(
          calculator,
          weight,
        ),
      };
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

  ExerciseCalorieEstimate? _distanceEstimate(
    ExerciseCalorieCalculator calculator,
    MetActivityDefinition activity,
    double weight,
  ) {
    final km = _parseOptionalDouble(_distanceController);
    if (km == null) {
      return null;
    }
    final factor = activity.netKcalPerKgKm;
    if (factor != null) {
      return calculator.estimateByDistanceFactor(
        weightKg: weight,
        distanceKm: km,
        netKcalPerKgKm: factor,
        sourceKey: activity.sourceKey,
      );
    }
    final speed = activity.referenceSpeedKmh;
    final met = _metState.metValue;
    if (speed == null || met == null) {
      return null;
    }
    return calculator.estimateByDistanceSpeed(
      met: met,
      weightKg: weight,
      distanceKm: km,
      speedKmh: speed,
      sourceKey: activity.sourceKey,
    );
  }

  ExerciseCalorieEstimate? _repsEstimate(
    ExerciseCalorieCalculator calculator,
    MetActivityDefinition activity,
    double weight,
  ) {
    final reps = _parseOptionalInt(_repsController);
    final met = _metState.metValue;
    if (reps == null || met == null) {
      return null;
    }
    return calculator.estimateByReps(
      met: met,
      weightKg: weight,
      reps: reps,
      sourceKey: activity.sourceKey,
    );
  }

  ExerciseCalorieEstimate? _durationEstimate(
    ExerciseCalorieCalculator calculator,
    double weight,
  ) {
    final duration = int.tryParse(_durationController.text.trim());
    final met = _metState.metValue;
    if (duration == null || duration <= 0 || met == null || met <= 0) {
      return null;
    }
    return calculator.estimate(
      met: met,
      weightKg: weight,
      durationMinutes: duration,
      sourceKey: _metState.sourceKey,
    );
  }

  Future<void> _save() async {
    final entry = _buildEntry();
    if (entry == null) {
      return;
    }

    var addTemplate = false;
    if (!widget.isEditing && entry.activityId == 'custom') {
      final saved = await widget.controller.listCustomActivityTemplates();
      final normalized = FoodSearchNormalizer.normalize(entry.name);
      final exists = saved.any(
        (item) => FoodSearchNormalizer.normalize(item.name) == normalized,
      );
      if (!exists) {
        if (!mounted) {
          return;
        }
        final answer = await showSaveCustomActivityTemplateDialog(
          context: context,
          activityName: entry.name,
        );
        if (answer == null || !mounted) {
          return;
        }
        addTemplate = answer;
      }
    }

    setState(() => _isSaving = true);
    if (widget.isEditing) {
      await widget.controller.updateExercise(entry);
    } else {
      await widget.controller.addExercise(entry);
    }
    if (addTemplate) {
      try {
        await widget.controller.saveCustomActivityTemplate(entry);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('テンプレートの追加に失敗しました')));
        }
      }
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

  Widget _icon(String asset) => AppIcon(
    asset,
    size: 24,
    color: IconCircle.foregroundOf(IconCircleTone.green),
  );

  Widget _numberField({
    required Key fieldKey,
    required String icon,
    required String label,
    required String suffix,
    required TextEditingController controller,
    required TextInputType keyboardType,
  }) {
    return DesignFieldCard(
      icon: _icon(icon),
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

  Future<void> _pickLoggedAt() async {
    final local = _loggedAt.toLocal();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: local,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(local),
    );
    if (pickedTime == null) {
      return;
    }
    setState(() {
      _loggedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatLoggedAt(DateTime value) {
    final local = value.toLocal();
    return '${local.year}/${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildAdditionalFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isStrength) ...[
          _numberField(
            fieldKey: ExerciseFormScreen.setsFieldKey,
            icon: AppIcons.dumbbell,
            label: 'セット',
            suffix: 'セット',
            controller: _setsController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: AppSpacing.md),
          _numberField(
            fieldKey: ExerciseFormScreen.liftWeightFieldKey,
            icon: AppIcons.dumbbell,
            label: '重量（kg）',
            suffix: 'kg',
            controller: _liftWeightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        DesignFieldCard(
          icon: _icon(AppIcons.calendar),
          label: '記録日時',
          child: DesignInputBox(
            onTap: _pickLoggedAt,
            child: Text(
              _formatLoggedAt(_loggedAt),
              style: AppTypography.bodyL.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      bottomBarPadding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        6,
        AppSpacing.screenHorizontal,
        6,
      ),
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignButton(
            label: widget.isEditing ? '更新' : '保存',
            showTrailingIcon: false,
            loading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            DesignButton(
              label: '削除',
              style: DesignButtonStyle.danger,
              showTrailingIcon: false,
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DesignTitleBlock(title: widget.isEditing ? '運動を編集' : '運動を追加'),
            ExerciseMetCalculationSection(
              controller: widget.controller,
              loggedAt: _loggedAt,
              durationController: _durationController,
              distanceController: _distanceController,
              repsController: _repsController,
              grossKcalController: _burnedKcalController,
              nameController: _nameController,
              notesController: _notesController,
              additionalFields: _buildAdditionalFields(),
              isEditing: widget.isEditing,
              initialEntry: widget.entry,
              onEstimateChanged: (state) => setState(() => _metState = state),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
