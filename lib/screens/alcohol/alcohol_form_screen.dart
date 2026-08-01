import 'package:flutter/material.dart';

import '../../models/alcohol_entry.dart';
import '../../services/alcohol_nutrition_calculator.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/alcohol_unit.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_text_field.dart';
import '../../widgets/common/primary_button.dart';
import '../../widgets/common/secondary_button.dart';
import '../../widgets/layout/app_constrained_bottom_bar.dart';
import '../../widgets/layout/app_form_constraint.dart';

class AlcoholFormScreen extends StatefulWidget {
  const AlcoholFormScreen({super.key, required this.controller, this.entry});

  final AppController controller;
  final AlcoholEntry? entry;

  bool get isEditing => entry != null;

  @override
  State<AlcoholFormScreen> createState() => _AlcoholFormScreenState();
}

class _AlcoholFormScreenState extends State<AlcoholFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  late final TextEditingController _alcoholPercentageController;
  late final TextEditingController _totalCaloriesController;
  late final TextEditingController _manualPureAlcoholController;
  late DateTime _consumedAt;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _nameController = TextEditingController(text: entry?.beverageName ?? '');
    _amountController = TextEditingController(
      text: entry?.amount.toString() ?? '',
    );
    _unitController = TextEditingController(text: entry?.unit ?? 'ml');
    _alcoholPercentageController = TextEditingController(
      text: entry?.alcoholPercentage.toString() ?? '',
    );
    _totalCaloriesController = TextEditingController(
      text: entry != null ? entry.totalCalories.toString() : '',
    );
    _manualPureAlcoholController = TextEditingController(
      text: entry != null && !isMilliliterUnit(entry.unit)
          ? entry.pureAlcoholGrams.toString()
          : '',
    );
    _consumedAt = entry?.consumedAt.toLocal() ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _unitController.dispose();
    _alcoholPercentageController.dispose();
    _totalCaloriesController.dispose();
    _manualPureAlcoholController.dispose();
    super.dispose();
  }

  double? _parseOptionalDouble(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return double.tryParse(trimmed);
  }

  AlcoholNutritionResult? _previewResult() {
    final amount = double.tryParse(_amountController.text.trim());
    final alcoholPercentage = double.tryParse(
      _alcoholPercentageController.text.trim(),
    );
    if (amount == null || alcoholPercentage == null) {
      return null;
    }

    return AlcoholNutritionCalculator.resolve(
      amount: amount,
      unit: _unitController.text,
      alcoholPercentage: alcoholPercentage,
      totalCaloriesInput: _parseOptionalDouble(_totalCaloriesController.text),
      manualPureAlcoholGrams: _parseOptionalDouble(
        _manualPureAlcoholController.text,
      ),
    );
  }

  AlcoholEntry? _buildEntry() {
    if (_formKey.currentState?.validate() != true) {
      return null;
    }

    final amount = double.parse(_amountController.text.trim());
    final alcoholPercentage = double.parse(
      _alcoholPercentageController.text.trim(),
    );
    final unit = normalizeAlcoholUnit(_unitController.text.trim());
    final canAutoCalculate = isMilliliterUnit(unit);
    final manualPure = _parseOptionalDouble(_manualPureAlcoholController.text);

    if (!canAutoCalculate && (manualPure == null || manualPure <= 0)) {
      return null;
    }

    final result = AlcoholNutritionCalculator.resolve(
      amount: amount,
      unit: unit,
      alcoholPercentage: alcoholPercentage,
      totalCaloriesInput: _parseOptionalDouble(_totalCaloriesController.text),
      manualPureAlcoholGrams: manualPure,
    );

    return AlcoholEntry(
      id: widget.entry?.id ?? widget.controller.generateId(),
      beverageName: _nameController.text.trim(),
      amount: amount,
      unit: unit,
      alcoholPercentage: alcoholPercentage,
      totalCalories: result.totalCalories,
      pureAlcoholGrams: result.pureAlcoholGrams,
      alcoholCalories: result.alcoholCalories,
      consumedAt: _consumedAt,
    );
  }

  Future<void> _pickConsumedAt() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _consumedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) {
      return;
    }

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_consumedAt),
    );
    if (pickedTime == null) {
      return;
    }

    setState(() {
      _consumedAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatConsumedAt() {
    final local = _consumedAt.toLocal();
    final date =
        '${local.year}/${local.month}/${local.day} '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
    return date;
  }

  Future<void> _save() async {
    final entry = _buildEntry();
    if (entry == null) {
      return;
    }

    setState(() => _isSaving = true);
    if (widget.isEditing) {
      await widget.controller.updateAlcohol(entry);
    } else {
      await widget.controller.addAlcohol(entry);
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
      message: '「${entry.beverageName}」を削除しますか？',
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.controller.deleteAlcohol(entry.id);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('アルコール記録の削除に失敗しました。もう一度お試しください')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewResult();
    final canAutoCalculate =
        preview?.canAutoCalculatePureAlcohol ??
        isMilliliterUnit(_unitController.text);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'アルコールを編集' : 'アルコールを追加'),
      ),
      body: SafeArea(
        child: AppFormConstraint(
          child: Form(
            key: _formKey,
            onChanged: () => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              children: [
                AppTextField(
                  controller: _nameController,
                  label: '飲料名',
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '飲料名を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: AppTextField(
                        controller: _amountController,
                        label: '数量',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final parsed = double.tryParse(value?.trim() ?? '');
                          if (parsed == null || parsed <= 0) {
                            return '0より大きい数値を入力してください';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppTextField(
                        controller: _unitController,
                        label: '単位',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '単位を入力';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                if (!canAutoCalculate) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'mlで入力すると純アルコール量を自動計算できます',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _manualPureAlcoholController,
                    label: '純アルコール量 (g)',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      if (canAutoCalculate) {
                        return null;
                      }
                      final parsed = double.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return '純アルコール量を入力してください';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _alcoholPercentageController,
                  label: 'アルコール度数 (%)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed < 0 || parsed > 100) {
                      return '0〜100の範囲で入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _totalCaloriesController,
                  label: '飲料全体のカロリー (kcal) — 任意',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  helper: '未入力時はアルコール由来の推定カロリーを使用します',
                  validator: (value) {
                    final trimmed = value?.trim() ?? '';
                    if (trimmed.isEmpty) {
                      return null;
                    }
                    final parsed = double.tryParse(trimmed);
                    if (parsed == null || parsed < 0) {
                      return '0以上の数値を入力してください';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('記録日時'),
                  subtitle: Text(_formatConsumedAt()),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: _pickConsumedAt,
                ),
                if (preview != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '計算結果',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _PreviewRow(
                          label: '純アルコール量',
                          value: '${formatNullableNutrient(preview.pureAlcoholGrams, fractionDigits: 1)} g',
                        ),
                        _PreviewRow(
                          label: 'アルコール由来',
                          value:
                              '${formatNullableNutrient(preview.alcoholCalories, fractionDigits: 0)} kcal',
                        ),
                        _PreviewRow(
                          label: preview.totalCaloriesIsEstimated
                              ? '飲料全体（推定）'
                              : '飲料全体',
                          value:
                              '${formatNullableNutrient(preview.totalCalories, fractionDigits: 0)} kcal',
                        ),
                        if (preview.totalCaloriesIsEstimated) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '推定値はアルコール由来カロリーのみです。'
                            '糖質等を含む飲料では実際のカロリーと異なる場合があります。',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.secondaryText),
                          ),
                        ],
                        const Divider(height: AppSpacing.lg),
                        _PreviewRow(
                          label: '摂取カロリーへの反映',
                          value:
                              '${formatNullableNutrient(preview.totalCalories, fractionDigits: 0)} kcal',
                          emphasized: true,
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxl),
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
              onPressed: _isSaving ? null : _save,
              label: widget.isEditing ? '更新する' : '保存する',
            ),
            if (widget.isEditing) ...[
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                onPressed: _isSaving ? null : _confirmDelete,
                label: '削除する',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final valueStyle = emphasized
        ? Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.primaryGreen,
            fontWeight: FontWeight.w700,
          )
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label)),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}
