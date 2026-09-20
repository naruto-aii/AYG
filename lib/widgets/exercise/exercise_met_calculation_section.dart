import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../data/met_intensity_presets.dart';
import '../../models/exercise_entry.dart';
import '../../models/exercise_calculation_source.dart';
import '../../models/exercise_category.dart';
import '../../services/exercise_calorie_calculator.dart';
import '../../services/exercise_weight_resolver.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_text_field.dart';
import '../../screens/settings/calculation_references_screen.dart';

/// 運動フォーム内の MET 自動計算（種目1回 + 分量 + 追加消費）。
class ExerciseMetCalculationSection extends StatefulWidget {
  const ExerciseMetCalculationSection({
    super.key,
    required this.controller,
    required this.loggedAt,
    required this.durationController,
    required this.grossKcalController,
    required this.isEditing,
    this.nameController,
    this.notesController,
    this.additionalFields,
    this.initialEntry,
    required this.onEstimateChanged,
  });

  final AppController controller;
  final DateTime loggedAt;
  final TextEditingController durationController;
  final TextEditingController grossKcalController;
  final TextEditingController? nameController;
  final TextEditingController? notesController;
  final Widget? additionalFields;
  final bool isEditing;
  final ExerciseEntry? initialEntry;
  final void Function(ExerciseMetFormState state) onEstimateChanged;

  @override
  State<ExerciseMetCalculationSection> createState() =>
      _ExerciseMetCalculationSectionState();
}

class ExerciseMetFormState {
  ExerciseMetFormState({
    this.category,
    this.activityId,
    this.intensity,
    this.metValue,
    this.grossKcal,
    this.netKcal,
    this.weightKgSnapshot,
    this.calculationSource,
    this.calculationVersion,
    this.sourceKey,
    this.manualOverride = false,
    this.includeInRemaining = true,
  });

  final ExerciseCategory? category;
  final String? activityId;
  final String? intensity;
  final double? metValue;
  final double? grossKcal;
  final double? netKcal;
  final double? weightKgSnapshot;
  final ExerciseCalculationSource? calculationSource;
  final String? calculationVersion;
  final String? sourceKey;
  final bool manualOverride;
  final bool includeInRemaining;
}

class _ExerciseMetCalculationSectionState
    extends State<ExerciseMetCalculationSection> {
  static const _calculator = ExerciseCalorieCalculator();
  static const _weightResolver = ExerciseWeightResolver();
  static const _walkActivityId = 'walk_brisk';
  static const _houseworkActivityId = 'housework';
  static const _customActivityId = 'custom';
  static const _noWeightMessage =
      '体重データがないため、消費カロリーを自動計算できません。'
      '体重を記録するか、手動で入力してください。';
  static const _houseworkPalWarning =
      'いつもの家事は、設定の生活活動係数にすでに含まれています。'
      '特別に長く動いた分だけ記録してください。';
  static const _lifestyleWalkMessage =
      '通勤などのいつもの移動は生活活動係数に含まれているので、'
      '追加消費には入れません。';

  MetActivityDefinition? _activity;
  String? _intensityId;
  bool _manualOverride = false;
  bool _allowRecalculateOnEdit = false;
  bool _showAdvanced = false;
  bool _showRename = false;
  bool _walkIsExtraExercise = true;
  WeightReference? _weightReference;
  ExerciseCalorieEstimate? _estimate;
  double? _displayNetKcal;
  double? _manualNetKcal;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry != null) {
      _activity = MetActivityCatalog.findById(entry.activityId);
      _intensityId = entry.intensity ?? _activity?.defaultIntensityId;
      _manualOverride =
          entry.calculationSource == ExerciseCalculationSource.manualOverride;
      _walkIsExtraExercise =
          entry.calculationSource !=
          ExerciseCalculationSource.lifestyleIncluded;
      _displayNetKcal = entry.netKcal ?? entry.effectiveNetKcal;
      _weightReference = entry.weightKgSnapshot != null
          ? WeightReference(
              weightKg: entry.weightKgSnapshot!,
              source: WeightReferenceSource.weightEntry,
            )
          : null;
      final catalogName = _activity?.displayName;
      _showRename =
          _isCustom ||
          (catalogName != null &&
              (entry.name).trim().isNotEmpty &&
              entry.name.trim() != catalogName);
    }
    widget.durationController.addListener(_onInputsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isEditing) {
        _notifyParent();
      } else {
        _notifyParent();
      }
    });
  }

  @override
  void dispose() {
    widget.durationController.removeListener(_onInputsChanged);
    super.dispose();
  }

  bool get _isWalk => _activity?.id == _walkActivityId;
  bool get _isHousework => _activity?.id == _houseworkActivityId;
  bool get _isCustom => _activity?.id == _customActivityId;
  bool get _includeInRemaining => !_isWalk || _walkIsExtraExercise;

  void _onInputsChanged() {
    _maybeRecalculate();
  }

  void _maybeRecalculate() {
    if (widget.isEditing && !_allowRecalculateOnEdit && !_manualOverride) {
      return;
    }
    _recalculate();
  }

  MetIntensityOption? get _selectedIntensity {
    if (_activity == null) {
      return null;
    }
    return _activity!.intensityById(_intensityId) ??
        _activity!.defaultIntensity;
  }

  double? get _resolvedMet => _manualOverride ? null : _selectedIntensity?.met;

  void _applyActivity(MetActivityDefinition activity) {
    _activity = activity;
    _intensityId = activity.defaultIntensityId;
    if (activity.id != _walkActivityId) {
      _walkIsExtraExercise = true;
    }
    if (activity.id != _customActivityId) {
      _showRename = false;
      _syncNameFromActivity();
    } else {
      _showRename = true;
      _syncNameFromActivity();
    }
  }

  void _syncNameFromActivity() {
    final nameController = widget.nameController;
    final activity = _activity;
    if (nameController == null || activity == null) {
      return;
    }
    nameController.text = activity.displayName;
  }

  void _recalculate() {
    if (_manualOverride) {
      _notifyParent();
      return;
    }

    _weightReference = _weightResolver.resolve(
      exerciseLoggedAt: widget.loggedAt,
      weightEntries: widget.controller.weightEntries,
      profile: widget.controller.profile,
    );

    final duration = int.tryParse(widget.durationController.text.trim());
    final met = _resolvedMet;
    if (_activity == null ||
        _weightReference == null ||
        duration == null ||
        duration <= 0 ||
        met == null) {
      setState(() {
        _estimate = null;
        if (!widget.isEditing || _allowRecalculateOnEdit) {
          _displayNetKcal = _includeInRemaining ? null : 0;
        }
      });
      _notifyParent();
      return;
    }

    final estimate = _calculator.estimate(
      met: met,
      weightKg: _weightReference!.weightKg,
      durationMinutes: duration,
      sourceKey: _selectedIntensity?.sourceKey ?? _activity?.sourceKey,
    );

    setState(() {
      _estimate = estimate;
      _displayNetKcal = _includeInRemaining ? estimate?.netKcal : 0;
      if (estimate != null) {
        widget.grossKcalController.text = estimate.grossKcal.toStringAsFixed(1);
      }
    });
    _notifyParent();
  }

  void _notifyParent() {
    final gross = double.tryParse(widget.grossKcalController.text.trim());
    final net = _manualOverride
        ? (_manualNetKcal ?? gross)
        : (_includeInRemaining ? _displayNetKcal : 0.0);
    widget.onEstimateChanged(
      ExerciseMetFormState(
        category: _activity?.category,
        activityId: _activity?.id,
        intensity: _intensityId,
        metValue: _manualOverride ? null : _resolvedMet,
        grossKcal: _includeInRemaining ? gross : (gross ?? 0.0),
        netKcal: net,
        weightKgSnapshot:
            _weightReference?.weightKg ?? widget.initialEntry?.weightKgSnapshot,
        calculationSource: _manualOverride
            ? ExerciseCalculationSource.manualOverride
            : (!_includeInRemaining
                  ? ExerciseCalculationSource.lifestyleIncluded
                  : (_estimate != null
                        ? ExerciseCalculationSource.metEstimate
                        : widget.initialEntry?.calculationSource)),
        calculationVersion:
            _estimate?.calculationVersion ??
            widget.initialEntry?.calculationVersion ??
            MetActivityCatalog.calculationVersion,
        sourceKey: _selectedIntensity?.sourceKey ?? _activity?.sourceKey,
        manualOverride: _manualOverride,
        includeInRemaining: _includeInRemaining,
      ),
    );
  }

  List<MetIntensityOption> get _intensityOptions {
    if (_activity == null) {
      return const [];
    }
    if (_activity!.intensityOptions.isEmpty) {
      return MetIntensityPresets.forCategory(_activity!.category);
    }
    return _activity!.intensityOptions;
  }

  List<MetActivityDefinition> get _visibleActivities {
    return MetActivityCatalog.activities;
  }

  @override
  Widget build(BuildContext context) {
    final intensities = _intensityOptions;
    final hasWeight =
        _weightReference != null ||
        widget.initialEntry?.weightKgSnapshot != null;
    final visibleActivities = _visibleActivities;
    final showNameField = widget.nameController != null && _showRename;
    final canShowNet =
        _activity != null &&
        (_estimate != null || _displayNetKcal != null || !_includeInRemaining);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('種目', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final activity in visibleActivities)
                ChoiceChip(
                  label: Text(activity.displayName),
                  selected: _activity?.id == activity.id,
                  onSelected: (_) {
                    setState(() {
                      _applyActivity(activity);
                    });
                    _maybeRecalculate();
                  },
                ),
            ],
          ),
          if (_activity == null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '種目を1つ選んでください',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_activity != null &&
              widget.nameController != null &&
              !_isCustom &&
              !_showRename)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showRename = true),
                child: const Text('名前を変える'),
              ),
            ),
          if (showNameField) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: widget.nameController,
              label: '表示名',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '表示名を入力してください';
                }
                return null;
              },
            ),
          ],
          if (_isWalk) ...[
            const SizedBox(height: AppSpacing.md),
            Text('これは？', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('追加の運動'),
                  selected: _walkIsExtraExercise,
                  onSelected: (_) {
                    setState(() => _walkIsExtraExercise = true);
                    _maybeRecalculate();
                  },
                ),
                ChoiceChip(
                  label: const Text('いつもの移動'),
                  selected: !_walkIsExtraExercise,
                  onSelected: (_) {
                    setState(() => _walkIsExtraExercise = false);
                    _maybeRecalculate();
                  },
                ),
              ],
            ),
            if (!_walkIsExtraExercise) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _lifestyleWalkMessage,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
          if (_isHousework) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _houseworkPalWarning,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (intensities.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('きつさ', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final option in intensities)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: _intensityId == option.id,
                    onSelected: _manualOverride
                        ? null
                        : (_) {
                            setState(() => _intensityId = option.id);
                            _maybeRecalculate();
                          },
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: widget.durationController,
            label: '実施時間（分）',
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return '実施時間を入力してください';
              }
              final parsed = int.tryParse(value);
              if (parsed == null || parsed <= 0) {
                return '1以上の整数を入力してください';
              }
              return null;
            },
          ),
          if (widget.additionalFields != null) ...[
            const SizedBox(height: AppSpacing.sm),
            widget.additionalFields!,
          ],
          if (_activity != null &&
              _includeInRemaining &&
              !hasWeight &&
              !_manualOverride) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _noWeightMessage,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (canShowNet) ...[
            const SizedBox(height: AppSpacing.md),
            Text('追加消費', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatNullableNutrient(_includeInRemaining ? _displayNetKcal : 0)} kcal',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              _includeInRemaining
                  ? '残りカロリーに加算される、運動による追加分'
                  : _lifestyleWalkMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          ExpansionTile(
            title: const Text('詳細設定'),
            initiallyExpanded: _showAdvanced,
            onExpansionChanged: (v) => setState(() => _showAdvanced = v),
            children: [
              if (widget.notesController != null)
                AppTextField(
                  controller: widget.notesController,
                  label: 'メモ',
                  maxLines: 3,
                ),
              if (_resolvedMet != null)
                ListTile(
                  dense: true,
                  title: const Text('内部 MET'),
                  trailing: Text(_resolvedMet!.toStringAsFixed(2)),
                ),
              if (_weightReference != null)
                ListTile(
                  dense: true,
                  title: const Text('計算に使用した体重'),
                  trailing: Text(
                    '${_weightReference!.weightKg.toStringAsFixed(1)} kg',
                  ),
                ),
              ListTile(
                dense: true,
                title: const Text('推定総消費（gross）'),
                subtitle: const Text('運動時間中の総エネルギー消費'),
                trailing: Text(
                  '${formatNullableNutrient(_estimate?.grossKcal ?? double.tryParse(widget.grossKcalController.text))} kcal',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('手動消費カロリー補正'),
                subtitle: const Text('追加消費（net）を手入力'),
                value: _manualOverride,
                onChanged: (value) {
                  setState(() {
                    _manualOverride = value;
                    if (value) {
                      _manualNetKcal =
                          _displayNetKcal ??
                          double.tryParse(
                            widget.grossKcalController.text.trim(),
                          );
                    }
                  });
                  _recalculate();
                },
              ),
              if (_manualOverride)
                TextField(
                  decoration: const InputDecoration(
                    labelText: '手動 追加消費 kcal（net）',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) {
                    _manualNetKcal = double.tryParse(value.trim());
                    _notifyParent();
                  },
                ),
              ListTile(
                dense: true,
                title: const Text('計算バージョン'),
                trailing: Text(MetActivityCatalog.calculationVersion),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => const CalculationReferencesScreen(),
                    ),
                  );
                },
                child: const Text('計算根拠・参考文献'),
              ),
            ],
          ),
          if (widget.isEditing && !_allowRecalculateOnEdit) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '保存済みの計算結果を、現在の入力内容と体重データで再計算します。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            TextButton(
              onPressed: () {
                setState(() => _allowRecalculateOnEdit = true);
                _recalculate();
              },
              child: const Text('再計算'),
            ),
          ],
        ],
      ),
    );
  }
}
