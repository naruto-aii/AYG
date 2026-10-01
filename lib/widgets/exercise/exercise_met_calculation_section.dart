import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../data/met_intensity_presets.dart';
import '../../models/exercise_entry.dart';
import '../../models/exercise_calculation_source.dart';
import '../../models/exercise_category.dart';
import '../../models/exercise_quantity_unit.dart';
import '../../services/exercise_calorie_calculator.dart';
import '../../services/exercise_weight_resolver.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/food_search_normalizer.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/icon_circle.dart';
import '../../screens/settings/calculation_references_screen.dart';

/// 運動フォーム内の MET 自動計算（種目1回 + 分量 + 追加消費）。
class ExerciseMetCalculationSection extends StatefulWidget {
  static const searchFieldKey = Key('exercise-activity-search');
  static const durationFieldKey = Key('exercise-duration');
  static const distanceFieldKey = Key('exercise-distance');
  static const repsFieldKey = Key('exercise-reps');

  const ExerciseMetCalculationSection({
    super.key,
    required this.controller,
    required this.loggedAt,
    required this.durationController,
    this.distanceController,
    this.repsController,
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
  final TextEditingController? distanceController;
  final TextEditingController? repsController;
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
    this.quantityUnit,
    this.distanceKm,
    this.reps,
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
  final ExerciseQuantityUnit? quantityUnit;
  final double? distanceKm;
  final int? reps;
}

class _ExerciseMetCalculationSectionState
    extends State<ExerciseMetCalculationSection> {
  static const _calculator = ExerciseCalorieCalculator();
  static const _weightResolver = ExerciseWeightResolver();
  static const _walkActivityId = 'walk_brisk';
  static const _customActivityId = 'custom';
  static const _noWeightMessage =
      '体重データがないため、消費カロリーを自動計算できません。'
      '体重を記録するか、手動で入力してください。';
  static const _lifestyleWalkMessage =
      '通勤などのいつもの移動は生活活動係数に含まれているので、'
      '追加消費には入れません。';

  late final TextEditingController _distanceController;
  late final TextEditingController _repsController;
  late final bool _ownsDistance;
  late final bool _ownsReps;
  final _searchController = TextEditingController();
  List<MetActivityDefinition> _searchResults = const [];

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
    _ownsDistance = widget.distanceController == null;
    _ownsReps = widget.repsController == null;
    _distanceController =
        widget.distanceController ??
        TextEditingController(
          text: widget.initialEntry?.distanceKm?.toString() ?? '',
        );
    _repsController =
        widget.repsController ??
        TextEditingController(
          text: widget.initialEntry?.reps?.toString() ?? '',
        );
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
    _distanceController.addListener(_onInputsChanged);
    _repsController.addListener(_onInputsChanged);
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
    _distanceController.removeListener(_onInputsChanged);
    _repsController.removeListener(_onInputsChanged);
    _searchController.dispose();
    if (_ownsDistance) {
      _distanceController.dispose();
    }
    if (_ownsReps) {
      _repsController.dispose();
    }
    super.dispose();
  }

  String get _lifestyleMessage {
    if (_isWalk) {
      return _lifestyleWalkMessage;
    }
    final name = _activity?.displayName ?? 'この活動';
    return '$nameは生活活動係数に含まれているので、追加消費には入れません。';
  }

  bool get _isWalk => _activity?.id == _walkActivityId;
  bool get _isCustom => _activity?.id == _customActivityId;
  bool get _includeInRemaining {
    if (_activity?.lifestyleIncluded == true) {
      return false;
    }
    if (_isWalk && !_walkIsExtraExercise) {
      return false;
    }
    return true;
  }

  ExerciseQuantityUnit get _quantityUnit =>
      _activity?.quantityUnit ?? ExerciseQuantityUnit.durationMin;

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

    if (_activity == null) {
      setState(() => _estimate = null);
      _notifyParent();
      return;
    }

    if (!_includeInRemaining) {
      setState(() {
        _estimate = null;
        _displayNetKcal = 0;
        if (!widget.isEditing || _allowRecalculateOnEdit) {
          widget.grossKcalController.text = '0';
        }
      });
      _notifyParent();
      return;
    }

    if (_weightReference == null) {
      setState(() {
        _estimate = null;
        if (!widget.isEditing || _allowRecalculateOnEdit) {
          _displayNetKcal = null;
        }
      });
      _notifyParent();
      return;
    }

    final estimate = _estimateForActivity();
    setState(() {
      _estimate = estimate;
      if (estimate != null) {
        _displayNetKcal = estimate.netKcal;
        widget.grossKcalController.text = estimate.grossKcal.toStringAsFixed(1);
      }
    });
    _notifyParent();
  }

  ExerciseCalorieEstimate? _estimateForActivity() {
    final activity = _activity;
    final weight = _weightReference?.weightKg;
    if (activity == null || weight == null) {
      return null;
    }
    final sourceKey = _selectedIntensity?.sourceKey ?? activity.sourceKey;
    switch (activity.quantityUnit) {
      case ExerciseQuantityUnit.distanceKm:
        final km = double.tryParse(_distanceController.text.trim());
        if (km == null) {
          return null;
        }
        final factor = activity.netKcalPerKgKm;
        if (factor != null) {
          return _calculator.estimateByDistanceFactor(
            weightKg: weight,
            distanceKm: km,
            netKcalPerKgKm: factor,
            sourceKey: sourceKey,
          );
        }
        final speed = activity.referenceSpeedKmh;
        final met = _resolvedMet;
        if (speed == null || met == null) {
          return null;
        }
        return _calculator.estimateByDistanceSpeed(
          met: met,
          weightKg: weight,
          distanceKm: km,
          speedKmh: speed,
          sourceKey: sourceKey,
        );
      case ExerciseQuantityUnit.reps:
        final reps = int.tryParse(_repsController.text.trim());
        final met = _resolvedMet;
        if (reps == null || met == null) {
          return null;
        }
        return _calculator.estimateByReps(
          met: met,
          weightKg: weight,
          reps: reps,
          sourceKey: sourceKey,
        );
      case ExerciseQuantityUnit.durationMin:
        final duration = int.tryParse(widget.durationController.text.trim());
        final met = _resolvedMet;
        if (duration == null || met == null) {
          return null;
        }
        return _calculator.estimate(
          met: met,
          weightKg: weight,
          durationMinutes: duration,
          sourceKey: sourceKey,
        );
    }
  }

  void _notifyParent() {
    final gross = double.tryParse(widget.grossKcalController.text.trim());
    final net = !_includeInRemaining
        ? 0.0
        : _manualOverride
        ? (_manualNetKcal ?? gross)
        : _displayNetKcal;
    final distanceKm = double.tryParse(_distanceController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    widget.onEstimateChanged(
      ExerciseMetFormState(
        category: _activity?.category,
        activityId: _activity?.id,
        intensity: _intensityId,
        metValue: _manualOverride || _activity?.netKcalPerKgKm != null
            ? null
            : _resolvedMet,
        grossKcal: _includeInRemaining ? gross : (gross ?? 0.0),
        netKcal: net,
        quantityUnit: _activity?.quantityUnit,
        distanceKm: distanceKm,
        reps: reps,
        weightKgSnapshot:
            _weightReference?.weightKg ?? widget.initialEntry?.weightKgSnapshot,
        calculationSource: !_includeInRemaining
            ? ExerciseCalculationSource.lifestyleIncluded
            : (_manualOverride
                  ? ExerciseCalculationSource.manualOverride
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

  void _onSearchChanged(String value) {
    setState(() {
      _searchResults = MetActivityCatalog.search(value);
    });
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
    required String hintText,
    required FormFieldValidator<String> validator,
    String? caption,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignFieldCard(
          icon: _icon(AppIcons.time),
          label: label,
          child: DesignInputBox(
            suffix: suffix,
            child: TextFormField(
              key: fieldKey,
              controller: controller,
              keyboardType: keyboardType,
              cursorColor: AppColors.textBrand,
              style: AppTypography.bodyL.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hintText,
                hintStyle: AppTypography.bodyL.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              validator: validator,
            ),
          ),
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            caption,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }

  Widget _quantityField() {
    switch (_quantityUnit) {
      case ExerciseQuantityUnit.distanceKm:
        return _numberField(
          fieldKey: ExerciseMetCalculationSection.distanceFieldKey,
          label: '距離（km）',
          suffix: 'km',
          controller: _distanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hintText: '5',
          validator: (value) {
            final parsed = double.tryParse(value?.trim() ?? '');
            if (parsed == null || parsed <= 0) {
              return '距離を入力してください';
            }
            return null;
          },
        );
      case ExerciseQuantityUnit.reps:
        return _numberField(
          fieldKey: ExerciseMetCalculationSection.repsFieldKey,
          label: '回数',
          suffix: '回',
          controller: _repsController,
          keyboardType: TextInputType.number,
          hintText: '10',
          validator: (value) {
            final parsed = int.tryParse(value?.trim() ?? '');
            if (parsed == null || parsed <= 0) {
              return '回数を入力してください';
            }
            return null;
          },
          caption: '消費カロリーは回数から計算します。1回を4秒として計算します。セット間の休憩は含みません。',
        );
      case ExerciseQuantityUnit.durationMin:
        return _numberField(
          fieldKey: ExerciseMetCalculationSection.durationFieldKey,
          label: '実施時間（分）',
          suffix: '分',
          controller: widget.durationController,
          keyboardType: TextInputType.number,
          hintText: '30',
          validator: (value) {
            final parsed = int.tryParse(value?.trim() ?? '');
            if (parsed == null || parsed <= 0) {
              return '1以上の整数を入力してください';
            }
            return null;
          },
        );
    }
  }

  List<Widget> _activityPicker() {
    final blank = FoodSearchNormalizer.normalize(
      _searchController.text,
    ).isEmpty;
    final activities = blank ? MetActivityCatalog.listed : _searchResults;
    if (activities.isEmpty) {
      return [
        const SizedBox(height: AppSpacing.md),
        Text(
          '一致する種目はありません',
          style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
        ),
      ];
    }
    return [
      const SizedBox(height: AppSpacing.md),
      DesignCard(
        child: Column(
          children: [
            for (final activity in activities)
              ListTile(
                title: Text(
                  activity.displayName,
                  style: AppTypography.bodyL.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  setState(() {
                    _applyActivity(activity);
                    _searchController.clear();
                    _searchResults = const [];
                  });
                  _maybeRecalculate();
                },
              ),
          ],
        ),
      ),
    ];
  }

  Widget _chipBox(List<Widget> chips) {
    return DesignInputBox(
      child: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: chips,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final intensities = _intensityOptions;
    final hasWeight =
        _weightReference != null ||
        widget.initialEntry?.weightKgSnapshot != null;
    final showNameField = widget.nameController != null && _showRename;
    final canShowNet =
        _activity != null &&
        (_estimate != null || _displayNetKcal != null || !_includeInRemaining);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DesignFieldCard(
          icon: _icon(AppIcons.exercise),
          label: '種目',
          child: DesignInputBox(
            child: TextField(
              key: ExerciseMetCalculationSection.searchFieldKey,
              controller: _searchController,
              onChanged: _onSearchChanged,
              cursorColor: AppColors.textBrand,
              style: AppTypography.bodyL.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: '名前の一部',
                hintStyle: AppTypography.bodyL.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        ..._activityPicker(),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              final custom = MetActivityCatalog.findById('custom');
              if (custom == null) {
                return;
              }
              setState(() {
                _applyActivity(custom);
                _searchController.clear();
                _searchResults = const [];
              });
              _maybeRecalculate();
            },
            child: const Text('その他（手入力）'),
          ),
        ),
        if (_activity != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _activity!.displayName,
            style: AppTypography.titleM.copyWith(color: AppColors.textPrimary),
          ),
        ],
        if (_activity == null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            '種目を1つ選んでください',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
        ],
        if (_activity != null &&
            widget.nameController != null &&
            !_isCustom &&
            !_showRename) ...[
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() => _showRename = true),
              child: const Text('名前を変える'),
            ),
          ),
        ],
        if (showNameField) ...[
          const SizedBox(height: AppSpacing.md),
          DesignFieldCard(
            icon: _icon(AppIcons.pen),
            label: '表示名',
            child: DesignInputBox(
              child: TextFormField(
                controller: widget.nameController,
                cursorColor: AppColors.textBrand,
                style: AppTypography.bodyL.copyWith(
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  hintText: '表示名',
                  hintStyle: AppTypography.bodyL.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '表示名を入力してください';
                  }
                  return null;
                },
              ),
            ),
          ),
        ],
        if (_isWalk) ...[
          const SizedBox(height: AppSpacing.md),
          DesignFieldCard(
            icon: _icon(AppIcons.exercise),
            label: 'これは？',
            child: _chipBox([
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
            ]),
          ),
          if (!_walkIsExtraExercise) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _lifestyleWalkMessage,
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
        if (_activity?.lifestyleIncluded == true) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _lifestyleMessage,
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
        ],
        if (intensities.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          DesignFieldCard(
            icon: _icon(AppIcons.heart),
            label: 'きつさ',
            child: _chipBox([
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
            ]),
          ),
        ],
        if (_activity != null) ...[
          const SizedBox(height: AppSpacing.md),
          _quantityField(),
        ],
        if (widget.additionalFields != null) ...[
          const SizedBox(height: AppSpacing.md),
          widget.additionalFields!,
        ],
        if (_activity != null &&
            _includeInRemaining &&
            !hasWeight &&
            !_manualOverride) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            _noWeightMessage,
            style: AppTypography.bodyS.copyWith(color: AppColors.textDanger),
          ),
        ],
        if (canShowNet) ...[
          const SizedBox(height: AppSpacing.md),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('追加消費', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '${formatNullableNutrient(_includeInRemaining ? _displayNetKcal : 0)} kcal',
                  style: AppTypography.valueL,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _includeInRemaining
                      ? '残りカロリーに加算される、運動による追加分'
                      : _lifestyleMessage,
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        ExpansionTile(
          title: const Text('詳細設定'),
          initiallyExpanded: _showAdvanced,
          onExpansionChanged: (v) => setState(() => _showAdvanced = v),
          children: [
            if (widget.notesController != null)
              DesignFieldCard(
                icon: _icon(AppIcons.pen),
                label: 'メモ',
                child: DesignInputBox(
                  child: DesignTextInput(
                    controller: widget.notesController!,
                    maxLines: 3,
                  ),
                ),
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
                        double.tryParse(widget.grossKcalController.text.trim());
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
          const SizedBox(height: AppSpacing.md),
          Text(
            '保存済みの計算結果を、現在の入力内容と体重データで再計算します。',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
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
    );
  }
}
