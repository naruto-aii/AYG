import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/meal_template.dart';
import '../../services/lock_screen_meal.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/icon_circle.dart';
import '../meal_template/meal_template_picker_screen.dart';

/// iOS 17 以降のロック画面に置く、食事テンプレート3ボタンの割り当て。
class LockScreenMealScreen extends StatefulWidget {
  const LockScreenMealScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LockScreenMealScreen> createState() => _LockScreenMealScreenState();
}

class _LockScreenMealScreenState extends State<LockScreenMealScreen> {
  final List<TextEditingController> _labels = [
    for (var slot = 0; slot < LockScreenMealConfig.slotCount; slot++)
      TextEditingController(),
  ];
  final List<String?> _templateIds = List<String?>.filled(
    LockScreenMealConfig.slotCount,
    null,
  );
  final List<String?> _templateNames = List<String?>.filled(
    LockScreenMealConfig.slotCount,
    null,
  );

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _labels) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final config = await widget.controller.loadLockScreenMealConfig();
    for (var slot = 0; slot < LockScreenMealConfig.slotCount; slot++) {
      final button = config.buttonAt(slot);
      _labels[slot].text = button.label;
      _templateIds[slot] = button.templateId;
      final templateId = button.templateId;
      if (templateId == null) {
        _templateNames[slot] = null;
        continue;
      }
      final bundle = await widget.controller.getMealTemplateWithItems(
        templateId,
      );
      _templateNames[slot] = bundle?.template.name;
    }
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _pickTemplate(int slot) async {
    final selected = await Navigator.of(context).push<MealTemplate>(
      MaterialPageRoute<MealTemplate>(
        builder: (context) =>
            MealTemplatePickerScreen(controller: widget.controller),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _templateIds[slot] = selected.templateId;
      _templateNames[slot] = selected.name;
    });
  }

  void _clearTemplate(int slot) {
    setState(() {
      _templateIds[slot] = null;
      _templateNames[slot] = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final config = LockScreenMealConfig(
      buttons: [
        for (var slot = 0; slot < LockScreenMealConfig.slotCount; slot++)
          LockScreenMealButtonConfig(
            slot: slot,
            label: _labels[slot].text.trim(),
            templateId: _templateIds[slot],
          ),
      ],
    );
    await widget.controller.saveLockScreenMealConfig(config);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Widget _icon(String asset) => AppIcon(
    asset,
    size: 24,
    color: IconCircle.foregroundOf(IconCircleTone.green),
  );

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      bottomBarPadding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        6,
        AppSpacing.screenHorizontal,
        6,
      ),
      bottomBar: DesignButton(
        key: const Key('lock-screen-meal-save'),
        label: '保存',
        showTrailingIcon: false,
        loading: _saving,
        onPressed: _loading || _saving ? null : _save,
      ),
      body: _loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DesignTitleBlock(
                  title: 'ロック画面',
                  subtitle:
                      'iOS 17以降のロック画面にボタンを3つ置きます。押すとアプリを開かず、割り当てたテンプレートを今日の食事として1件登録します。未課金のときは登録せず、ロック画面に有料機能と出ます。',
                ),
                for (
                  var slot = 0;
                  slot < LockScreenMealConfig.slotCount;
                  slot++
                ) ...[
                  if (slot > 0) const SizedBox(height: AppSpacing.md),
                  _buttonCard(slot),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
    );
  }

  Widget _buttonCard(int slot) {
    final templateName = _templateNames[slot];
    final assigned = _templateIds[slot] != null;
    return DesignFieldCard(
      icon: _icon(AppIcons.meal),
      label: 'ボタン${slot + 1}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignInputBox(
            child: DesignTextInput(
              key: Key('lock-screen-meal-label-$slot'),
              controller: _labels[slot],
              hintText: '表示する文字',
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignInputBox(
            key: Key('lock-screen-meal-template-$slot'),
            onTap: () => _pickTemplate(slot),
            child: Text(
              assigned ? (templateName ?? 'テンプレートが見つかりません') : '食事テンプレートを選ぶ',
              style: AppTypography.bodyL.copyWith(
                color: assigned ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          if (assigned) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: Key('lock-screen-meal-clear-$slot'),
                onPressed: () => _clearTemplate(slot),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.textMuted,
                ),
                child: Text(
                  '割り当てを外す',
                  style: AppTypography.labelM.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
