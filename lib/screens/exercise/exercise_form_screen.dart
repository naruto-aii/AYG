import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/exercise_category.dart';
import '../../models/exercise_entry.dart';
import '../../models/workout_template.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
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
  late DateTime _loggedAt;
  bool _isSaving = false;
  ExerciseMetFormState _metState = ExerciseMetFormState();
  List<String> _nameSuggestions = const [];

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
    _nameController.addListener(_onNameChanged);
    if (!widget.isEditing) {
      unawaited(_loadInitialSuggestions());
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_onNameChanged);
    _nameController.dispose();
    _durationController.dispose();
    _burnedKcalController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialSuggestions() async {
    if (widget.isEditing) {
      return;
    }
    final results = await widget.controller.getExerciseNameSuggestions();
    if (!mounted) {
      return;
    }
    setState(() => _nameSuggestions = results.take(20).toList());
  }

  Future<void> _onNameChanged() async {
    if (widget.isEditing) {
      return;
    }
    final query = _nameController.text.trim();
    if (query.isEmpty) {
      await _loadInitialSuggestions();
      return;
    }
    final results = await widget.controller.getExerciseNameSuggestions();
    if (!mounted) {
      return;
    }
    final normalizedQuery = query.toLowerCase();
    setState(() {
      _nameSuggestions = results
          .where((name) => name.toLowerCase().contains(normalizedQuery))
          .take(20)
          .toList();
    });
  }

  ExerciseEntry? _buildEntry() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }

    final gross = double.parse(_burnedKcalController.text);
    final net = _metState.netKcal ?? gross;

    return ExerciseEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      name: _nameController.text.trim(),
      durationMin: int.parse(_durationController.text),
      burnedKcal: gross,
      loggedAt: _loggedAt,
      category: _metState.category,
      activityId: _metState.activityId,
      intensity: _metState.intensity,
      metValue: _metState.metValue,
      grossKcal: gross,
      netKcal: net,
      weightKgSnapshot: _metState.weightKgSnapshot,
      calculationSource: _metState.calculationSource,
      calculationVersion:
          _metState.calculationVersion ?? MetActivityCatalog.calculationVersion,
      sourceKey: _metState.sourceKey,
    );
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
      onRestore: (restored) => widget.controller.addExercise(restored),
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
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
                if (!widget.isEditing) ...[
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SecondaryButton(
                          onPressed: () => openWorkoutTemplatePicker(
                            context: context,
                            controller: widget.controller,
                          ),
                          label: 'テンプレートから追加',
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        SecondaryButton(
                          onPressed: () => openWorkoutTemplateCreate(
                            context,
                            widget.controller,
                          ),
                          label: 'テンプレートを新規作成',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: '運動名',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '運動名を入力してください';
                          }
                          return null;
                        },
                      ),
                      if (!widget.isEditing && _nameSuggestions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: [
                            for (final suggestion in _nameSuggestions)
                              ActionChip(
                                label: Text(suggestion),
                                onPressed: () {
                                  _nameController.text = suggestion;
                                },
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _durationController,
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
                      const SizedBox(height: AppSpacing.sm),
                      LoggedAtPickerField(
                        loggedAt: _loggedAt,
                        onChanged: (value) => setState(() => _loggedAt = value),
                      ),
                      AppTextField(
                        controller: _burnedKcalController,
                        label: '消費 kcal（gross）',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '消費 kcal を入力してください';
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed < 0) {
                            return '0以上の数値を入力してください';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ExerciseMetCalculationSection(
                  controller: widget.controller,
                  loggedAt: _loggedAt,
                  durationController: _durationController,
                  grossKcalController: _burnedKcalController,
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
                      const SnackBar(content: Text('運動名と実施時間を入力してください')),
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
