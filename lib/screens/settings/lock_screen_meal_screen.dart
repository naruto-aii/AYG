import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/meal_template.dart';
import '../../models/meal_template_draft.dart';
import '../../services/lock_screen_meal.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/id_generator.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/icon_circle.dart';
import '../meal_template/meal_template_form_screen.dart';
import 'widget_exercise_pattern_screen.dart';

/// 保存はボタンの中身だけ。ホーム画面とロック画面への追加手順。
const String widgetPlacementLead =
    'アプリの中で保存しただけでは、ホーム画面やロック画面に自動では付きません。保存は、ボタンの文字と中身をこのiPhoneに覚えるだけです。';

const String widgetPlacementSteps =
    'ホーム画面（アプリアイコンのページ）\n'
    'いちばん左のページを長押し → 左上「編集」→「ウィジェットを追加」→「カロナビ」\n'
    '\n'
    'ロック画面\n'
    'ロック画面を長押し →「カスタマイズ」→「ロック画面」→ 時刻の上下の枠をタップ →「カロナビ」→「完了」';

/// ホームの大ウィジェット（食事3、運動2）とロック画面（同じ食事3）の中身。
///
/// ここでのパターンは食事テンプレートの4件とは別です。
class LockScreenMealScreen extends StatefulWidget {
  const LockScreenMealScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<LockScreenMealScreen> createState() => _LockScreenMealScreenState();
}

class _ButtonEditors {
  _ButtonEditors(List<LockScreenMealButtonConfig> buttons)
    : labels = List.generate(buttons.length, (_) => TextEditingController()),
      kinds = [for (final button in buttons) button.kind],
      names = [for (final button in buttons) button.contentName],
      items = [
        for (final button in buttons) [...button.items],
      ],
      exercises = [
        for (final button in buttons) [...button.exercises],
      ];

  final List<TextEditingController> labels;
  final List<WidgetPatternKind> kinds;
  final List<String?> names;
  final List<List<MealTemplateItem>> items;
  final List<List<WidgetExercisePattern>> exercises;

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
    _fill(_home, config.homeButtons);
    _fill(_lock, config.lockButtons);
    for (var slot = 0; slot < LockScreenMealConfig.lockSlotCount; slot++) {
      final shared = _home.items[slot].isNotEmpty
          ? _home.items[slot]
          : _lock.items[slot];
      final name = _home.names[slot] ?? _lock.names[slot];
      _home.items[slot] = [...shared];
      _lock.items[slot] = [...shared];
      _home.names[slot] = name;
      _lock.names[slot] = name;
    }
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  void _fill(_ButtonEditors editors, List<LockScreenMealButtonConfig> buttons) {
    for (var slot = 0; slot < buttons.length; slot++) {
      final button = buttons[slot];
      editors.labels[slot].text = button.label;
      editors.kinds[slot] = button.kind;
      editors.names[slot] = button.contentName;
      editors.items[slot] = [...button.items];
      editors.exercises[slot] = [...button.exercises];
    }
  }

  Future<void> _editMeal(int slot) async {
    final currentName = _home.names[slot]?.trim();
    final selected = await Navigator.of(context).push<MealTemplateDraft>(
      MaterialPageRoute<MealTemplateDraft>(
        builder: (context) => MealTemplateFormScreen(
          controller: widget.controller,
          captureOnly: true,
          initialDraft: MealTemplateDraft(
            name: (currentName == null || currentName.isEmpty)
                ? _home.labels[slot].text.trim()
                : currentName,
            items: [
              for (final item in _home.items[slot])
                MealTemplateItemDraft.fromTemplateItem(item),
            ],
          ),
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    final now = DateTime.now();
    final items = [
      for (final draft in selected.items)
        draft.toItem(itemId: draft.itemId ?? generateUniqueId(), now: now),
    ];
    setState(() {
      _home.items[slot] = items;
      _lock.items[slot] = [...items];
      _home.names[slot] = selected.name;
      _lock.names[slot] = selected.name;
    });
  }

  Future<void> _editExercise(int slot) async {
    final selected = await Navigator.of(context)
        .push<List<WidgetExercisePattern>>(
          MaterialPageRoute<List<WidgetExercisePattern>>(
            builder: (context) =>
                WidgetExercisePatternScreen(initial: _home.exercises[slot]),
          ),
        );
    if (selected == null || !mounted) {
      return;
    }
    setState(() => _home.exercises[slot] = selected);
  }

  void _clearMeal(int slot) {
    setState(() {
      _home.items[slot] = [];
      _lock.items[slot] = [];
      _home.names[slot] = null;
      _lock.names[slot] = null;
    });
  }

  void _clearExercise(int slot) {
    setState(() => _home.exercises[slot] = []);
  }

  List<LockScreenMealButtonConfig> _readHome() {
    return [
      for (var slot = 0; slot < _home.labels.length; slot++)
        LockScreenMealButtonConfig(
          slot: slot,
          label: _home.labels[slot].text.trim(),
          kind: _home.kinds[slot],
          contentName: _home.names[slot],
          items: _home.kinds[slot] == WidgetPatternKind.meal
              ? _home.items[slot]
              : const [],
          exercises: _home.kinds[slot] == WidgetPatternKind.exercise
              ? _home.exercises[slot]
              : const [],
        ),
    ];
  }

  List<LockScreenMealButtonConfig> _readLock() {
    return [
      for (var slot = 0; slot < _lock.labels.length; slot++)
        LockScreenMealButtonConfig(
          slot: slot,
          label: _lock.labels[slot].text.trim(),
          kind: WidgetPatternKind.meal,
          contentName: _home.names[slot],
          items: _home.items[slot],
        ),
    ];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await widget.controller.saveLockScreenMealConfig(
      LockScreenMealConfig(homeButtons: _readHome(), lockButtons: _readLock()),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('内容を保存しました'),
        content: const Text('$widgetPlacementLead\n\n$widgetPlacementSteps'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
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
                      'ホーム画面の大きなウィジェットは、残りカロリーに加え、食事3つと運動2つをワンタッチで登録します。ロック画面は同じ食事3つです。このパターンは食事テンプレートの4件とは別です。',
                ),
                DesignCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ウィジェットの置き方', style: AppTypography.titleM),
                      const SizedBox(height: AppSpacing.sm),
                      Text(widgetPlacementLead, style: AppTypography.bodyS),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        widgetPlacementSteps,
                        style: AppTypography.bodyS.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('ホーム画面', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.md),
                for (var slot = 0; slot < _home.labels.length; slot++) ...[
                  if (slot > 0) const SizedBox(height: AppSpacing.md),
                  _buttonCard(slot, prefix: 'home'),
                ],
                const SizedBox(height: AppSpacing.md),
                Text('ロック画面', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.md),
                for (var slot = 0; slot < _lock.labels.length; slot++) ...[
                  if (slot > 0) const SizedBox(height: AppSpacing.md),
                  _buttonCard(slot, prefix: 'lock'),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
    );
  }

  Widget _buttonCard(int slot, {required String prefix}) {
    final exercise =
        prefix == 'home' && _home.kinds[slot] == WidgetPatternKind.exercise;
    final label = exercise ? '運動パターン ${slot - 2}' : '食事パターン ${slot + 1}';
    final summary = exercise
        ? _exerciseSummary(_home.exercises[slot])
        : _mealSummary(_home.items[slot]);
    final assigned = summary != null;
    return DesignFieldCard(
      icon: _icon(exercise ? AppIcons.exercise : AppIcons.meal),
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DesignInputBox(
            child: DesignTextInput(
              key: Key('lock-screen-meal-label-$prefix-$slot'),
              controller: prefix == 'home'
                  ? _home.labels[slot]
                  : _lock.labels[slot],
              hintText: '表示する文字',
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignInputBox(
            key: Key('lock-screen-meal-template-$prefix-$slot'),
            onTap: exercise ? () => _editExercise(slot) : () => _editMeal(slot),
            child: Text(
              summary ?? (exercise ? '運動の内容を入れる' : '食事の内容を入れる'),
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
                onPressed: exercise
                    ? () => _clearExercise(slot)
                    : () => _clearMeal(slot),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.textMuted,
                ),
                child: Text(
                  '内容を消す',
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

  String? _mealSummary(List<MealTemplateItem> items) {
    if (items.isEmpty) {
      return null;
    }
    return items.map((item) => item.name).join('、');
  }

  String? _exerciseSummary(List<WidgetExercisePattern> items) {
    final usable = items.where((item) => item.canRegister).toList();
    if (usable.isEmpty) {
      return null;
    }
    return usable.map(widgetExercisePatternLabel).join('、');
  }
}
