import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
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

/// 運動フォーム内の MET 自動計算セクション。
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

  ExerciseCategory _category = ExerciseCategory.aerobic;
  MetActivityDefinition? _activity;
  String? _intensity;
  bool _manualOverride = false;
  bool _allowRecalculateOnEdit = false;
  WeightReference? _weightReference;
  ExerciseCalorieEstimate? _estimate;
  double? _displayNetKcal;

  @override
  void initState() {
    super.initState();
    final entry = widget.initialEntry;
    if (entry != null) {
      _category = entry.category ?? ExerciseCategory.aerobic;
      _activity = MetActivityCatalog.findById(entry.activityId);
      _intensity = entry.intensity;
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
      _activity = MetActivityCatalog.activities.first;
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

  double? get _resolvedMet {
    if (_activity == null) {
      return null;
    }
    if (_intensity != null) {
      for (final option in _activity!.intensityOptions) {
        if (option.label == _intensity) {
          return option.met;
        }
      }
    }
    return _activity!.defaultMet;
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
    if (_weightReference == null ||
        duration == null ||
        duration <= 0 ||
        met == null) {
      setState(() {
        _estimate = null;
        _displayNetKcal = null;
      });
      _notifyParent();
      return;
    }

    final estimate = _calculator.estimate(
      met: met,
      weightKg: _weightReference!.weightKg,
      durationMinutes: duration,
      sourceKey: _activity?.sourceKey,
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
    widget.onEstimateChanged(
      ExerciseMetFormState(
        category: _category,
        activityId: _activity?.id,
        intensity: _intensity,
        metValue: _manualOverride ? null : _resolvedMet,
        grossKcal: gross,
        netKcal: _manualOverride ? gross : _displayNetKcal,
        weightKgSnapshot:
            _weightReference?.weightKg ?? widget.initialEntry?.weightKgSnapshot,
        calculationSource: _manualOverride
            ? ExerciseCalculationSource.manualOverride
            : (_estimate != null
                  ? ExerciseCalculationSource.metEstimate
                  : null),
        calculationVersion:
            _estimate?.calculationVersion ??
            MetActivityCatalog.calculationVersion,
        sourceKey: _activity?.sourceKey,
        manualOverride: _manualOverride,
      ),
    );
  }

  String _weightLabel() {
    final ref =
        _weightReference ??
        (widget.initialEntry?.weightKgSnapshot != null
            ? WeightReference(
                weightKg: widget.initialEntry!.weightKgSnapshot!,
                source: WeightReferenceSource.weightEntry,
              )
            : null);
    if (ref == null) {
      return '体重記録がありません。プロフィールに体重を設定するか、体重を記録してください。';
    }
    final source = switch (ref.source) {
      WeightReferenceSource.weightEntry => '体重記録',
      WeightReferenceSource.profile => 'プロフィール',
    };
    return '参照体重: ${ref.weightKg.toStringAsFixed(1)} kg（$source）';
  }

  @override
  Widget build(BuildContext context) {
    final activityOptions = MetActivityCatalog.byCategory(_category);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<ExerciseCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: '運動分類'),
            items: ExerciseCategory.values
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
                _activity =
                    MetActivityCatalog.byCategory(value).firstOrNull ??
                    MetActivityCatalog.activities.first;
                _intensity = null;
              });
              _maybeRecalculate();
            },
          ),
          const SizedBox(height: AppSpacing.sm),
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
                _intensity = null;
              });
              _maybeRecalculate();
            },
          ),
          if (_activity != null && _activity!.intensityOptions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _intensity,
              decoration: const InputDecoration(labelText: '強度'),
              items: _activity!.intensityOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option.label,
                      child: Text('${option.label} (MET ${option.met})'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() => _intensity = value);
                _maybeRecalculate();
              },
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(_weightLabel(), style: Theme.of(context).textTheme.bodySmall),
          if (_estimate != null || _displayNetKcal != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '推定 gross: ${formatNullableNutrient(_estimate?.grossKcal ?? double.tryParse(widget.grossKcalController.text))} kcal · '
              'net: ${formatNullableNutrient(_displayNetKcal)} kcal',
            ),
          ],
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('消費 kcal を手動入力'),
            value: _manualOverride,
            onChanged: (value) {
              setState(() => _manualOverride = value);
              _recalculate();
            },
          ),
          if (widget.isEditing && !_allowRecalculateOnEdit) ...[
            TextButton(
              onPressed: () {
                setState(() => _allowRecalculateOnEdit = true);
                _recalculate();
              },
              child: const Text('保存済みの値を再計算する'),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const CalculationReferencesScreen(),
                  ),
                );
              },
              child: const Text('計算根拠・参考文献'),
            ),
          ),
        ],
      ),
    );
  }
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
