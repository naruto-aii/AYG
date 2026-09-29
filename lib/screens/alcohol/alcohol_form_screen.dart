import 'package:flutter/material.dart';

import '../../models/alcohol_entry.dart';
import '../../services/alcohol_nutrition_calculator.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../../utils/alcohol_unit.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/icon_circle.dart';

/// アルコールの追加・編集。
///
/// Figma: SP / 07 アルコールを追加（29:843）
class AlcoholFormScreen extends StatefulWidget {
  const AlcoholFormScreen({
    super.key,
    required this.controller,
    this.entry,
    this.initialConsumedAt,
  });

  final AppController controller;
  final AlcoholEntry? entry;
  final DateTime? initialConsumedAt;

  bool get isEditing => entry != null;

  @override
  State<AlcoholFormScreen> createState() => _AlcoholFormScreenState();
}

class _AlcoholFormScreenState extends State<AlcoholFormScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _unitController;
  late final TextEditingController _alcoholPercentageController;
  late final TextEditingController _totalCaloriesController;
  late final TextEditingController _manualPureAlcoholController;
  late DateTime _consumedAt;
  bool _isSaving = false;
  bool _totalCaloriesManuallyEdited = false;

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
    _consumedAt =
        (entry?.consumedAt ?? widget.initialConsumedAt ?? DateTime.now())
            .toLocal();
    if (entry != null) {
      _totalCaloriesManuallyEdited =
          (entry.totalCalories - entry.alcoholCalories).abs() > 0.01;
    }
    _totalCaloriesController.addListener(_onTotalCaloriesEdited);
    for (final controller in _watchedControllers) {
      controller.addListener(_onAnyFieldChanged);
    }
  }

  List<TextEditingController> get _watchedControllers => [
    _nameController,
    _amountController,
    _unitController,
    _alcoholPercentageController,
    _totalCaloriesController,
    _manualPureAlcoholController,
  ];

  void _onTotalCaloriesEdited() {
    _totalCaloriesManuallyEdited = true;
  }

  void _onAnyFieldChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    for (final controller in _watchedControllers) {
      controller.removeListener(_onAnyFieldChanged);
    }
    _totalCaloriesController.removeListener(_onTotalCaloriesEdited);
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
    return trimmed.isEmpty ? null : double.tryParse(trimmed);
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
      totalCaloriesInput: _totalCaloriesManuallyEdited
          ? _parseOptionalDouble(_totalCaloriesController.text)
          : null,
      manualPureAlcoholGrams: _parseOptionalDouble(
        _manualPureAlcoholController.text,
      ),
    );
  }

  void _warn(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  AlcoholEntry? _buildEntry() {
    if (_nameController.text.trim().isEmpty) {
      _warn('飲料名を入力してください');
      return null;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _warn('数量は0より大きい数値を入力してください');
      return null;
    }

    final alcoholPercentage = double.tryParse(
      _alcoholPercentageController.text.trim(),
    );
    if (alcoholPercentage == null ||
        alcoholPercentage < 0 ||
        alcoholPercentage > 100) {
      _warn('アルコール度数は0〜100の範囲で入力してください');
      return null;
    }

    final unit = normalizeAlcoholUnit(_unitController.text.trim());
    if (unit.isEmpty) {
      _warn('単位を入力してください');
      return null;
    }

    final canAutoCalculate = isMilliliterUnit(unit);
    final manualPure = _parseOptionalDouble(_manualPureAlcoholController.text);
    if (!canAutoCalculate && (manualPure == null || manualPure <= 0)) {
      _warn('ml以外の単位では純アルコール量を入力してください');
      return null;
    }

    final totalCaloriesInput = _totalCaloriesManuallyEdited
        ? _parseOptionalDouble(_totalCaloriesController.text)
        : null;
    if (totalCaloriesInput != null && totalCaloriesInput < 0) {
      _warn('カロリーは0以上の数値を入力してください');
      return null;
    }

    final result = AlcoholNutritionCalculator.resolve(
      amount: amount,
      unit: unit,
      alcoholPercentage: alcoholPercentage,
      totalCaloriesInput: totalCaloriesInput,
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
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return '${local.year}年${local.month}月${local.day}日'
        '（${weekdays[local.weekday - 1]}）'
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
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
        _warn('アルコール記録の削除に失敗しました。もう一度お試しください');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewResult();
    final canAutoCalculate =
        preview?.canAutoCalculatePureAlcohol ??
        isMilliliterUnit(_unitController.text);

    return DesignPage(
      bottomBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DesignButton(
            label: widget.isEditing ? '更新する' : '追加する',
            showTrailingIcon: false,
            loading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
          if (widget.isEditing) ...[
            const SizedBox(height: 8),
            DesignButton(
              label: '削除する',
              style: DesignButtonStyle.danger,
              showTrailingIcon: false,
              onPressed: _isSaving ? null : _confirmDelete,
            ),
          ],
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: DesignBackButton(),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isEditing ? 'アルコールを編集' : 'アルコールを追加',
            style: AppTypography.headingL,
          ),
          const SizedBox(height: 4),
          Text(
            'お酒の種類と量から、\n純アルコール量とカロリーを計算します。',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          DesignRowField(
            label: '飲料名',
            child: DesignInputBox(
              radius: AppRadius.sm,
              trailing: const AppIcon(
                AppIcons.search,
                size: 16,
                color: AppColors.iconMuted,
              ),
              child: DesignTextInput(
                controller: _nameController,
                hintText: '例）ビール、ワイン、日本酒など',
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignRowField(
            label: '数量',
            child: DesignInputBox(
              radius: AppRadius.sm,
              verticalPadding: 11,
              trailing: SizedBox(
                width: 92,
                child: DesignTextInput(
                  controller: _unitController,
                  hintText: '単位',
                  textAlign: TextAlign.end,
                ),
              ),
              child: DesignTextInput(
                controller: _amountController,
                hintText: '350',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignRowField(
            label: 'アルコール度数 (%)',
            labelWidth: 138,
            child: DesignInputBox(
              radius: AppRadius.sm,
              verticalPadding: 11,
              suffix: '%',
              child: DesignTextInput(
                controller: _alcoholPercentageController,
                hintText: '5',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignRowField(
            label: '純アルコール量 (g)',
            labelWidth: 138,
            child: DesignInputBox(
              radius: AppRadius.sm,
              verticalPadding: 11,
              suffix: 'g',
              child: canAutoCalculate
                  // ml のときは数量と度数から自動で決まるので読み取り専用。
                  ? Text(
                      preview == null
                          ? '自動計算'
                          : preview.pureAlcoholGrams.toStringAsFixed(1),
                      style: AppTypography.bodyL.copyWith(
                        color: preview == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    )
                  : DesignTextInput(
                      controller: _manualPureAlcoholController,
                      hintText: '20.0',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
            ),
          ),
          if (!canAutoCalculate) ...[
            const SizedBox(height: 6),
            Text(
              'mlで入力すると純アルコール量を自動計算できます',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          DesignRowField(
            label: '飲料全体のカロリー',
            labelWidth: 138,
            child: DesignInputBox(
              radius: AppRadius.sm,
              verticalPadding: 11,
              suffix: 'kcal',
              child: DesignTextInput(
                controller: _totalCaloriesController,
                hintText: preview == null
                    ? '任意'
                    : preview.alcoholCalories.toStringAsFixed(0),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          DesignRowField(
            label: '記録日時',
            child: DesignInputBox(
              radius: AppRadius.sm,
              onTap: _pickConsumedAt,
              trailing: const AppIcon(
                AppIcons.calendar,
                size: 16,
                color: AppColors.iconMuted,
              ),
              child: Text(
                _formatConsumedAt(),
                style: AppTypography.bodyL.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          if (preview != null) ...[
            const SizedBox(height: 12),
            _ResultCard(result: preview),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Figma: 「この内容での計算結果」カード。
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final AlcoholNutritionResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgSurfaceGreenSoft,
        borderRadius: AppRadius.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DesignIcon(
                Symbols.bar_chart_rounded,
                size: 18,
                color: AppColors.iconPrimary,
              ),
              const SizedBox(width: 6),
              Text('この内容での計算結果', style: AppTypography.titleM),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ResultItem(
                  icon: const DesignIcon(
                    Symbols.water_drop_rounded,
                    size: 18,
                    color: AppColors.iconPrimary,
                  ),
                  label: '純アルコール',
                  value: result.pureAlcoholGrams.toStringAsFixed(1),
                  unit: 'g',
                  note: '（純アルコール 1g＝7 kcal）',
                ),
              ),
              Expanded(
                child: _ResultItem(
                  icon: AppIcon(
                    AppIcons.alcohol,
                    size: 18,
                    color: IconCircle.foregroundOf(IconCircleTone.green),
                  ),
                  label: 'アルコール由来',
                  value: result.alcoholCalories.toStringAsFixed(0),
                  unit: 'kcal',
                ),
              ),
              Expanded(
                child: _ResultItem(
                  icon: const DesignIcon(
                    Symbols.sync_rounded,
                    size: 18,
                    color: AppColors.iconPrimary,
                  ),
                  label: '摂取への反映',
                  value: result.totalCalories.toStringAsFixed(0),
                  unit: 'kcal',
                  note: result.totalCaloriesIsEstimated
                      ? 'アルコール由来のみの推定値です'
                      : '今日のアルコールとして記録されます',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultItem extends StatelessWidget {
  const _ResultItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.note,
  });

  final Widget icon;
  final String label;
  final String value;
  final String unit;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconCircle(size: 30, child: icon),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.labelS.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.valueM,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: AppTypography.labelS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(
            note!,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}
