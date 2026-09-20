import 'package:flutter/material.dart';

import '../../models/strength_workout_log.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../common/app_text_field.dart';
import '../common/secondary_button.dart';

const suggestedStrengthNames = [
  'ベンチプレス',
  'スクワット',
  'デッドリフト',
  'ショルダープレス',
  'ラットプルダウン',
  'ベントオーバーロウ',
  'アームカール',
  'トライセプス',
  'レッグプレス',
  'プランク',
];

class StrengthWorkoutLogEditor extends StatefulWidget {
  const StrengthWorkoutLogEditor({
    super.key,
    required this.initialLog,
    required this.onChanged,
  });

  final StrengthWorkoutLog? initialLog;
  final ValueChanged<StrengthWorkoutLog> onChanged;

  @override
  State<StrengthWorkoutLogEditor> createState() =>
      _StrengthWorkoutLogEditorState();
}

class _StrengthWorkoutLogEditorState extends State<StrengthWorkoutLogEditor> {
  late List<_ExerciseDraft> _exercises;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialLog?.exercises ?? const [];
    _exercises = initial.isEmpty
        ? [_ExerciseDraft.empty()]
        : initial.map(_ExerciseDraft.fromLog).toList();
  }

  @override
  void dispose() {
    for (final exercise in _exercises) {
      exercise.dispose();
    }
    super.dispose();
  }

  void _notify() {
    widget.onChanged(
      StrengthWorkoutLog(
        exercises: _exercises
            .map((exercise) => exercise.toLog())
            .where((exercise) => exercise.name.isNotEmpty)
            .toList(),
      ),
    );
  }

  void _addExercise({String name = ''}) {
    if (name.isNotEmpty) {
      final emptyIndex = _exercises.indexWhere(
        (exercise) => exercise.nameController.text.trim().isEmpty,
      );
      if (emptyIndex >= 0) {
        setState(() {
          _exercises[emptyIndex].nameController.text = name;
        });
        _notify();
        return;
      }
    }
    setState(() {
      _exercises.add(_ExerciseDraft.empty(name: name));
    });
    _notify();
  }

  void _removeExercise(int index) {
    if (_exercises.length == 1) {
      _exercises[index].nameController.clear();
      for (final set in _exercises[index].sets) {
        set.weightController.clear();
        set.repsController.clear();
      }
      setState(() {});
      _notify();
      return;
    }
    setState(() {
      _exercises.removeAt(index).dispose();
    });
    _notify();
  }

  void _addSet(int exerciseIndex) {
    setState(() {
      final sets = _exercises[exerciseIndex].sets;
      final last = sets.last;
      _exercises[exerciseIndex].sets.add(
        _SetDraft(
          weightController: TextEditingController(
            text: last.weightController.text,
          ),
          repsController: TextEditingController(text: last.repsController.text),
        ),
      );
    });
    _notify();
  }

  void _removeSet(int exerciseIndex, int setIndex) {
    final exercise = _exercises[exerciseIndex];
    if (exercise.sets.length == 1) {
      exercise.sets.first.weightController.clear();
      exercise.sets.first.repsController.clear();
      setState(() {});
      _notify();
      return;
    }
    setState(() {
      exercise.sets.removeAt(setIndex).dispose();
    });
    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('種目の記録', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'ジムと同じく、種目ごとにセット・重量・回数を残せます。消費カロリーは上の実施時間から計算します。',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final name in suggestedStrengthNames)
              ActionChip(
                label: Text(name),
                onPressed: () => _addExercise(name: name),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var exerciseIndex = 0; exerciseIndex < _exercises.length; exerciseIndex++)
          _ExerciseCard(
            draft: _exercises[exerciseIndex],
            onChanged: _notify,
            onRemove: () => _removeExercise(exerciseIndex),
            onAddSet: () => _addSet(exerciseIndex),
            onRemoveSet: (setIndex) => _removeSet(exerciseIndex, setIndex),
          ),
        SecondaryButton(
          label: '種目を追加',
          icon: Icons.add,
          onPressed: _addExercise,
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.draft,
    required this.onChanged,
    required this.onRemove,
    required this.onAddSet,
    required this.onRemoveSet,
  });

  final _ExerciseDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  final VoidCallback onAddSet;
  final ValueChanged<int> onRemoveSet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: draft.nameController,
                      label: '種目名',
                      hint: 'ベンチプレス',
                      onChanged: (_) => onChanged(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'この種目を削除',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              for (var setIndex = 0; setIndex < draft.sets.length; setIndex++)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: SizedBox(
                          width: 56,
                          child: Text(
                            'セット${setIndex + 1}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      Expanded(
                        child: AppTextField(
                          controller: draft.sets[setIndex].weightController,
                          label: '重量（kg）',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: AppTextField(
                          controller: draft.sets[setIndex].repsController,
                          label: '回数',
                          keyboardType: TextInputType.number,
                          onChanged: (_) => onChanged(),
                        ),
                      ),
                      IconButton(
                        tooltip: 'このセットを削除',
                        onPressed: () => onRemoveSet(setIndex),
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAddSet,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('セットを追加'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseDraft {
  _ExerciseDraft({required this.nameController, required this.sets});

  factory _ExerciseDraft.empty({String name = ''}) {
    return _ExerciseDraft(
      nameController: TextEditingController(text: name),
      sets: [_SetDraft.empty()],
    );
  }

  factory _ExerciseDraft.fromLog(StrengthExerciseLog log) {
    return _ExerciseDraft(
      nameController: TextEditingController(text: log.name),
      sets: log.sets.isEmpty
          ? [_SetDraft.empty()]
          : log.sets.map(_SetDraft.fromLog).toList(),
    );
  }

  final TextEditingController nameController;
  final List<_SetDraft> sets;

  StrengthExerciseLog toLog() {
    return StrengthExerciseLog(
      name: nameController.text.trim(),
      sets: sets
          .map((set) => set.toLog())
          .where((set) => !set.isEmpty)
          .toList(),
    );
  }

  void dispose() {
    nameController.dispose();
    for (final set in sets) {
      set.dispose();
    }
  }
}

class _SetDraft {
  _SetDraft({required this.weightController, required this.repsController});

  factory _SetDraft.empty() {
    return _SetDraft(
      weightController: TextEditingController(),
      repsController: TextEditingController(),
    );
  }

  factory _SetDraft.fromLog(StrengthSetLog set) {
    return _SetDraft(
      weightController: TextEditingController(
        text: set.weightKg?.toString() ?? '',
      ),
      repsController: TextEditingController(text: set.reps?.toString() ?? ''),
    );
  }

  final TextEditingController weightController;
  final TextEditingController repsController;

  StrengthSetLog toLog() {
    return StrengthSetLog(
      weightKg: double.tryParse(weightController.text.trim()),
      reps: int.tryParse(repsController.text.trim()),
    );
  }

  void dispose() {
    weightController.dispose();
    repsController.dispose();
  }
}
