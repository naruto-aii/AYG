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

/// ホームの大ウィジェット（5ボタン）とロック画面（3ボタン）の割り当て。
class LockScreenMealScreen extends StatefulWidget {
  const LockScreenMealScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LockScreenMealScreen> createState() => _LockScreenMealScreenState();
}

class _ButtonEditors {
  _ButtonEditors(List<LockScreenMealButtonConfig> buttons)
    : labels = List.generate(buttons.length, (_) => TextEditingController()),
      templateIds = [for (final button in buttons) button.templateId],
      templateNames = List<String?>.filled(buttons.length, null);

  final List<TextEditingController> labels;
  final List<String?> templateIds;
  final List<String?> templateNames;

  void dispose() {
    for (final controller in labels) {
      controller.dispose();
    }
  }
}

class _LockScreenMealScreenState extends State<LockScreenMealScreen> {
  late final _ButtonEditors _home = _ButtonEditors(
    LockScreenMealConfig.defaults().homeButtons,
  );
  late final _ButtonEditors _lock = _ButtonEditors(
    LockScreenMealConfig.defaults().lockButtons,
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
    _home.dispose();
    _lock.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await widget.controller.loadLockScreenMealConfig();
    await _fill(_home, config.homeButtons);
    await _fill(_lock, config.lockButtons);
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _fill(
    _ButtonEditors editors,
    List<LockScreenMealButtonConfig> buttons,
  ) async {
    for (var slot = 0; slot < buttons.length; slot++) {
      final button = buttons[slot];
      editors.labels[slot].text = button.label;
      editors.templateIds[slot] = button.templateId;
      final templateId = button.templateId;
      if (templateId == null) {
        editors.templateNames[slot] = null;
        continue;
      }
      final bundle = await widget.controller.getMealTemplateWithItems(
        templateId,
      );
      editors.templateNames[slot] = bundle?.template.name;
    }
  }

  Future<void> _pickTemplate(_ButtonEditors editors, int slot) async {
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
      editors.templateIds[slot] = selected.templateId;
      editors.templateNames[slot] = selected.name;
    });
  }

  void _clearTemplate(_ButtonEditors editors, int slot) {
    setState(() {
      editors.templateIds[slot] = null;
      editors.templateNames[slot] = null;
    });
  }

  List<LockScreenMealButtonConfig> _read(_ButtonEditors editors) {
    return [
      for (var slot = 0; slot < editors.labels.length; slot++)
        LockScreenMealButtonConfig(
          slot: slot,
          label: editors.labels[slot].text.trim(),
          templateId: editors.templateIds[slot],
        ),
    ];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.controller.saveLockScreenMealConfig(
      LockScreenMealConfig(
        homeButtons: _read(_home),
        lockButtons: _read(_lock),
      ),
    );
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
                  title: 'ウィジェット',
                  subtitle:
                      'ホーム画面の大きなウィジェットにボタンを5つ、ロック画面に朝・昼・夜の3つを置きます。文字と食事テンプレートはそれぞれ決められます。押すとアプリを開かず、そのテンプレートを1件登録します。',
                ),
                Text('ホーム画面', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.md),
                for (var slot = 0; slot < _home.labels.length; slot++) ...[
                  if (slot > 0) const SizedBox(height: AppSpacing.md),
                  _buttonCard(_home, slot, prefix: 'home'),
                ],
                const SizedBox(height: AppSpacing.md),
                Text('ロック画面', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.md),
                for (var slot = 0; slot < _lock.labels.length; slot++) ...[
                  if (slot > 0) const SizedBox(height: AppSpacing.md),
                  _buttonCard(_lock, slot, prefix: 'lock'),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
    );
  }

  Widget _buttonCard(
    _ButtonEditors editors,
    int slot, {
    required String prefix,
  }) {
    final templateName = editors.templateNames[slot];
    final assigned = editors.templateIds[slot] != null;
    return DesignFieldCard(
      icon: _icon(AppIcons.meal),
      label: 'ボタン${slot + 1}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignInputBox(
            child: DesignTextInput(
              key: Key('lock-screen-meal-label-$prefix-$slot'),
              controller: editors.labels[slot],
              hintText: '表示する文字',
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignInputBox(
            key: Key('lock-screen-meal-template-$prefix-$slot'),
            onTap: () => _pickTemplate(editors, slot),
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
                onPressed: () => _clearTemplate(editors, slot),
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
