import 'package:flutter/material.dart';

import '../../models/weight_entry.dart';
import '../../state/app_controller.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/logged_at_picker_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/layout/app_constrained_bottom_bar.dart';
import '../../widgets/layout/app_form_constraint.dart';

class WeightRecordScreen extends StatefulWidget {
  const WeightRecordScreen({
    super.key,
    required this.controller,
    this.entry,
    this.initialWeightKg,
    this.initialRecordedAt,
  });

  final AppController controller;
  final WeightEntry? entry;
  final double? initialWeightKg;
  final DateTime? initialRecordedAt;

  bool get isEditing => entry != null;

  @override
  State<WeightRecordScreen> createState() => _WeightRecordScreenState();
}

class _WeightRecordScreenState extends State<WeightRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late DateTime _recordedAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _weightController = TextEditingController(
      text:
          entry?.weightKg.toStringAsFixed(1) ??
          widget.initialWeightKg?.toStringAsFixed(1) ??
          '',
    );
    _recordedAt =
        (entry?.recordedAt ?? widget.initialRecordedAt ?? DateTime.now())
            .toLocal();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    setState(() => _isSaving = true);
    final weightKg = double.parse(_weightController.text);

    if (widget.isEditing) {
      await widget.controller.updateWeightEntry(
        widget.entry!.copyWith(weightKg: weightKg, recordedAt: _recordedAt),
      );
    } else {
      await widget.controller.recordManualWeight(
        weightKg,
        recordedAt: _recordedAt,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(widget.isEditing ? '体重を更新しました' : '体重を記録しました')),
    );
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
      message: 'この体重記録を削除しますか？',
    );
    if (confirmed != true) {
      return;
    }

    try {
      await widget.controller.deleteWeightEntry(entry.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('体重記録の削除に失敗しました。もう一度お試しください')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isEditing ? '体重を編集' : '体重を記録')),
      body: SafeArea(
        child: AppFormConstraint(
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
                      Text(
                        widget.isEditing ? '体重記録を編集' : '体重を入力してください',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (widget.controller.useHealthIntegration) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Health同期がONの場合、Healthの体重を優先して利用します。',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _weightController,
                        label: '体重 (kg)',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '体重を入力してください';
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed < 30 || parsed > 300) {
                            return '30〜300 kg の範囲で入力してください';
                          }
                          return null;
                        },
                      ),
                      LoggedAtPickerField(
                        loggedAt: _recordedAt,
                        label: '記録日時',
                        onChanged: (value) =>
                            setState(() => _recordedAt = value),
                      ),
                    ],
                  ),
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
              label: widget.isEditing ? '更新' : '記録する',
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
