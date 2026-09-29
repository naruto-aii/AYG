import 'package:flutter/material.dart';

import '../../models/weight_entry.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../../utils/local_date.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/icon_circle.dart';
import '../../widgets/common/app_confirm_dialog.dart';

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
    final weightKg = double.tryParse(_weightController.text.trim());
    if (weightKg == null || weightKg < 30 || weightKg > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('体重は 30〜300 kg の範囲で入力してください')),
      );
      return;
    }

    setState(() => _isSaving = true);

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

  Future<void> _pickRecordedAt() async {
    final local = _recordedAt.toLocal();
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
      _recordedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  /// この記録より前の、いちばん新しい記録。
  WeightEntry? get _previous {
    final entries = [...widget.controller.weightEntries]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    for (final entry in entries) {
      if (entry.id == widget.entry?.id) {
        continue;
      }
      if (entry.recordedAt.isBefore(_recordedAt)) {
        return entry;
      }
    }
    return null;
  }

  Widget _icon(String asset) => AppIcon(
    asset,
    size: 24,
    color: IconCircle.foregroundOf(IconCircleTone.green),
  );

  @override
  Widget build(BuildContext context) {
    final local = _recordedAt.toLocal();
    final previous = _previous;
    final current = double.tryParse(_weightController.text.trim());

    return DesignPage(
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignButton(
            label: widget.isEditing ? '更新' : '記録する',
            showTrailingIcon: false,
            loading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 8),
            DesignButton(
              label: 'この記録を削除',
              style: DesignButtonStyle.danger,
              showTrailingIcon: false,
              onPressed: _confirmDelete,
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignTitleBlock(
            title: widget.isEditing ? '体重を編集' : '体重を記録',
            subtitle: '朝いちばんに測ると、ぶれが少なくなります。',
          ),
          DesignFieldCard(
            icon: _icon(AppIcons.scale),
            label: '体重（kg）',
            child: DesignInputBox(
              suffix: 'kg',
              child: DesignTextInput(
                controller: _weightController,
                hintText: '60.0',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignFieldCard(
            icon: _icon(AppIcons.calendar),
            label: '記録日時',
            child: DesignInputBox(
              onTap: _pickRecordedAt,
              child: Text(
                '${formatJapaneseDateWithWeekday(local)} '
                '${local.hour}:${local.minute.toString().padLeft(2, '0')}',
                style: AppTypography.bodyL.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (previous != null) ...[
            const SizedBox(height: 10),
            DesignCard(
              elevated: false,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '前回の記録',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        previous.weightKg.toStringAsFixed(1),
                        style: AppTypography.valueL,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'kg',
                        style: AppTypography.labelS.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    current == null
                        ? formatJapaneseDateWithWeekday(previous.recordedAt)
                        : '${formatJapaneseDateWithWeekday(previous.recordedAt)}から '
                              '${current - previous.weightKg >= 0 ? '+' : ''}'
                              '${(current - previous.weightKg).toStringAsFixed(1)} kg',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textBrand,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (widget.controller.useHealthIntegration) ...[
            const SizedBox(height: 10),
            Text(
              'Health同期がONの場合、Healthの体重を優先して利用します。',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
