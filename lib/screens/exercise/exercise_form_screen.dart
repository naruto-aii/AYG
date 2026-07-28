import 'package:flutter/material.dart';

import '../../models/exercise_entry.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';

class ExerciseFormScreen extends StatefulWidget {
  const ExerciseFormScreen({super.key, required this.controller, this.entry});

  final AppController controller;
  final ExerciseEntry? entry;

  bool get isEditing => entry != null;

  @override
  State<ExerciseFormScreen> createState() => _ExerciseFormScreenState();
}

class _ExerciseFormScreenState extends State<ExerciseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _durationController;
  late final TextEditingController _burnedKcalController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameController = TextEditingController(text: entry?.name ?? '');
    _durationController = TextEditingController(
      text: entry?.durationMin.toString() ?? '',
    );
    _burnedKcalController = TextEditingController(
      text: entry?.burnedKcal.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _burnedKcalController.dispose();
    super.dispose();
  }

  ExerciseEntry? _buildEntry() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }

    return ExerciseEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      name: _nameController.text.trim(),
      durationMin: int.parse(_durationController.text),
      burnedKcal: double.parse(_burnedKcalController.text),
      loggedAt: widget.entry?.loggedAt ?? DateTime.now(),
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

    final confirmed = await showAppConfirmDialog(
      context: context,
      title: '削除確認',
      message: '「${entry.name}」を削除しますか？',
    );

    if (confirmed != true) {
      return;
    }

    await widget.controller.deleteExercise(entry.id);
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
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              AppSpacing.md,
              widget.isEditing ? 160 : 100,
            ),
            children: [
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
                    AppTextField(
                      controller: _burnedKcalController,
                      label: '消費 kcal',
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
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Theme(
                data: Theme.of(context).copyWith(
                  filledButtonTheme: FilledButtonThemeData(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                  ),
                ),
                child: PrimaryButton(
                  label: '保存',
                  loading: _isSaving,
                  onPressed: _isSaving ? null : _save,
                ),
              ),
              if (widget.isEditing) ...[
                const SizedBox(height: AppSpacing.xs),
                SecondaryButton(label: '削除', onPressed: _confirmDelete),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
