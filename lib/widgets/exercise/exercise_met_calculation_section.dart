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
import '../../screens/settings/calculation_references_screen.dart';

/// 運動フォーム内の MET 自動計算（日常語 UI / 詳細設定折りたたみ）。
class ExerciseMetCalculationSection extends StatefulWidget {
  const ExerciseMetCalculationSection({
    super.key,
    required this.controller,
    required this.loggedAt,
    required this.durationController,
    required this.grossKcalController,
    required this.isEditing,
    this.initialEntry,
    required this.onEstimateChanged,
  });

  final AppController controller;
  final DateTime loggedAt;
  final TextEditingController durationController;
  final TextEditingController grossKcalController;
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
}

class _ExerciseMetCalculationSectionState
    extends State<ExerciseMetCalculationSection> {
  static const _calculator = ExerciseCalorieCalculator();
  static const _weightResolver = ExerciseWeightResolver();
  static const _noWeightMessage =
      '体重データがないため、消費カロリーを自動計算できません。'
      '体重を記録するか、手動で入力してください。';

  ExerciseCategory _category = ExerciseCategory.aerobic;
  MetActivityDefinition? _activity;
  String? _intensityId;
  bool _manualOverride = false;
  bool _allowRecalculateOnEdit = false;
  bool _showAdvanced = false;
  WeightReference? _weightReference;
  ExerciseCalorieEstimate? _estimate;
  double? _displayNetKcal;
  double? _manualNetKcal;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry != null) {
      _category = entry.category ?? ExerciseCategory.aerobic;
      _activity = MetActivityCatalog.findById(entry.activityId);
      _intensityId = entry.intensity;
      _manualOverride =
          entry.calculationSource == ExerciseCalculationSource.manualOverride;
      _displayNetKcal = entry.netKcal ?? entry.effectiveNetKcal;
      _weightReference = entry.weightKgSnapshot != null
          ? WeightReference(
              weightKg: entry.weightKgSnapshot!,
              source: WeightReferenceSource.weightEntry,
            )
          : null;
    } else {
      final list = MetActivityCatalog.byCategory(_category);
      _activity = list.isNotEmpty
          ? list.first
          : MetActivityCatalog.activities.first;
      _intensityId = _activity?.defaultIntensityId;
    }
    widget.durationController.addListener(_onInputsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!widget.isEditing) {
        _recalculate();
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
    if (_weightReference == null ||
        duration == null ||
        duration <= 0 ||
        met == null) {
      setState(() {
        _estimate = null;
        if (!widget.isEditing || _allowRecalculateOnEdit) {
          _displayNetKcal = null;
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
      _displayNetKcal = estimate?.netKcal;
      if (estimate != null) {
        widget.grossKcalController.text = estimate.grossKcal.toStringAsFixed(1);
      }
    });
    _notifyParent();
  }

  void _notifyParent() {
    final gross = double.tryParse(widget.grossKcalController.text.trim());
    final net = _manualOverride ? (_manualNetKcal ?? gross) : _displayNetKcal;
    widget.onEstimateChanged(
      ExerciseMetFormState(
        category: _category,
        activityId: _activity?.id,
        intensity: _intensityId,
        metValue: _manualOverride ? null : _resolvedMet,
        grossKcal: gross,
        netKcal: net,
        weightKgSnapshot:
            _weightReference?.weightKg ?? widget.initialEntry?.weightKgSnapshot,
        calculationSource: _manualOverride
            ? ExerciseCalculationSource.manualOverride
            : (_estimate != null
                  ? ExerciseCalculationSource.metEstimate
                  : widget.initialEntry?.calculationSource),
        calculationVersion:
            _estimate?.calculationVersion ??
            widget.initialEntry?.calculationVersion ??
            MetActivityCatalog.calculationVersion,
        sourceKey: _selectedIntensity?.sourceKey ?? _activity?.sourceKey,
        manualOverride: _manualOverride,
      ),
    );
  }

  List<MetIntensityOption> get _intensityOptions {
    if (_activity == null || _activity!.intensityOptions.isEmpty) {
      return MetIntensityPresets.forCategory(_category);
    }
    return _activity!.intensityOptions;
  }

  @override
  Widget build(BuildContext context) {
    final activityOptions = MetActivityCatalog.byCategory(_category);
    final intensities = _intensityOptions;
    final hasWeight =
        _weightReference != null ||
        widget.initialEntry?.weightKgSnapshot != null;

    return AppCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('1. 運動の種類', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<ExerciseCategory>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: '運動の種類'),
              items: MetActivityCatalog.selectableCategories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category,
                      child: Text(category.labelJa),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _category = value;
                  final next = MetActivityCatalog.byCategory(value);
                  _activity = next.isNotEmpty ? next.first : null;
                  _intensityId = _activity?.defaultIntensityId;
                });
                _maybeRecalculate();
              },
            ),
            const SizedBox(height: AppSpacing.md),
            Text('2. 種目', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            DropdownButtonFormField<MetActivityDefinition>(
              initialValue: _activity,
              decoration: const InputDecoration(labelText: '種目'),
              items: activityOptions
                  .map(
                    (activity) => DropdownMenuItem(
                      value: activity,
                      child: Text(activity.displayName),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _activity = value;
                  _intensityId = value?.defaultIntensityId;
                });
                _maybeRecalculate();
              },
            ),
            if (intensities.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '3. きつさ・運動強度',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              ...intensities.map((option) {
                return RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  title: Text(option.label),
                  subtitle: Text(option.description),
                  value: option.id,
                  groupValue: _intensityId,
                  onChanged: _manualOverride
                      ? null
                      : (value) {
                          setState(() => _intensityId = value);
                          _maybeRecalculate();
                        },
                );
              }),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              '4. 運動時間は上のフォームで入力してください',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            if (!hasWeight && !_manualOverride)
              Text(
                _noWeightMessage,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_estimate != null || _displayNetKcal != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                '5. 推定消費カロリー',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '推定総消費：${formatNullableNutrient(_estimate?.grossKcal ?? double.tryParse(widget.grossKcalController.text))} kcal\n'
                '（運動時間中の総エネルギー消費）',
              ),
              Text(
                '追加消費：${formatNullableNutrient(_displayNetKcal)} kcal\n'
                '（安静時消費を除いた、運動による追加分）',
              ),
            ],
            ExpansionTile(
              title: const Text('詳細設定'),
              initiallyExpanded: _showAdvanced,
              onExpansionChanged: (v) => setState(() => _showAdvanced = v),
              children: [
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
                        builder: (context) =>
                            const CalculationReferencesScreen(),
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
      ),
    );
  }
}
