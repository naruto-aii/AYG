import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/meal_template.dart';
import '../../models/meal_template_draft.dart';
import '../../models/workout_template.dart';
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
import 'widget_template_amount_screen.dart';

/// 保存はボタンの中身だけ。ホーム画面とロック画面への追加手順。
const String widgetPlacementLead =
    'アプリの中で保存しただけでは、ホーム画面やロック画面に自動では付きません。保存は、ボタンの文字と中身をこのiPhoneに覚えるだけです。';

const String widgetPlacementSteps =
    'ホーム画面（アプリアイコンのページ）\n'
    'いちばん左のページを長押し → 左上「編集」→「ウィジェットを追加」→「カロナビ」\n'
    '\n'
    'ロック画面\n'
    'ロック画面を長押し →「カスタマイズ」→「ロック画面」→ 時刻の上下の枠をタップ →「カロナビ」→「完了」';

/// ホームの大ウィジェット5枠と、その1〜3枠目を使うロック画面。
///
/// 枠ごとに食事か運動を選ぶ。ここでのパターンは食事テンプレートの4件とは別です。
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

  bool _loading = true;
  bool _saving = false;
  List<MealTemplate> _mealTemplates = const [];
  List<WorkoutTemplate> _workoutTemplates = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _home.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await widget.controller.loadLockScreenMealConfig();
    _fill(_home, config.homeButtons);
    try {
      _mealTemplates = await widget.controller.mealTemplatesForWidget();
      _workoutTemplates = await widget.controller.workoutTemplatesForWidget();
    } catch (_) {
      _mealTemplates = const [];
      _workoutTemplates = const [];
    }
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  void _fill(_ButtonEditors editors, List<LockScreenMealButtonConfig> buttons) {
    for (var slot = 0; slot < buttons.length; slot++) {
      final button = buttons[slot];
      editors.labels[slot].text = widgetButtonLabelForKind(
        kind: button.kind,
        label: button.label,
      );
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
      settings: const RouteSettings(name: 'lock_screen_meal_screen_MaterialPageRoute_0'),
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
      _home.names[slot] = selected.name;
    });
  }

  /// テンプレートを選んだら、構成ごとの量を入れる画面へ進む。
  Future<void> _pickMealTemplate(int slot, String templateId) async {
    final bundle = await widget.controller.getMealTemplateWithItems(templateId);
    if (!mounted || bundle == null || bundle.items.isEmpty) {
      return;
    }
    final items = [...bundle.items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final selected = await Navigator.of(context).push<MealTemplateDraft>(
      MaterialPageRoute<MealTemplateDraft>(
        settings: const RouteSettings(name: 'widget_meal_template_amount'),
        builder: (context) => WidgetMealAmountScreen(
          templateName: bundle.template.name,
          items: items,
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    final now = DateTime.now();
    setState(() {
      _home.items[slot] = [
        for (final draft in selected.items)
          draft.toItem(itemId: generateUniqueId(), now: now),
      ];
      _home.names[slot] = selected.name;
      _fillLabel(slot, selected.name);
    });
  }

  Future<void> _pickWorkoutTemplate(int slot, String templateId) async {
    final bundle = await widget.controller.getWorkoutTemplateWithItems(
      templateId,
    );
    if (!mounted || bundle == null || bundle.items.isEmpty) {
      return;
    }
    final items = [...bundle.items]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final selected = await Navigator.of(context)
        .push<List<WidgetExercisePattern>>(
          MaterialPageRoute<List<WidgetExercisePattern>>(
            settings: const RouteSettings(
              name: 'widget_workout_template_amount',
            ),
            builder: (context) => WidgetWorkoutAmountScreen(
              templateName: bundle.template.name,
              items: items,
            ),
          ),
        );
    if (selected == null || selected.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _home.exercises[slot] = selected;
      _fillLabel(slot, bundle.template.name);
    });
  }

  /// ボタンの文字が空なら、テンプレート名（8文字まで）を入れる。
  void _fillLabel(int slot, String name) {
    if (_home.labels[slot].text.trim().isNotEmpty) {
      return;
    }
    final characters = name.trim().characters;
    _home.labels[slot].text = characters.take(8).toString();
  }

  Future<void> _editExercise(int slot) async {
    final selected = await Navigator.of(context)
        .push<List<WidgetExercisePattern>>(
          MaterialPageRoute<List<WidgetExercisePattern>>(
      settings: const RouteSettings(name: 'lock_screen_meal_screen_MaterialPageRoute_1'),
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
      _home.names[slot] = null;
    });
  }

  void _setKind(int slot, WidgetPatternKind kind) {
    if (_home.kinds[slot] == kind) {
      return;
    }
    setState(() {
      _home.kinds[slot] = kind;
      _home.labels[slot].text = '';
      _home.items[slot] = [];
      _home.exercises[slot] = [];
      _home.names[slot] = null;
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
    final home = _readHome();
    return [
      for (var slot = 0; slot < LockScreenMealConfig.lockSlotCount; slot++)
        LockScreenMealButtonConfig(
          slot: slot,
          label: home[slot].label,
          kind: home[slot].kind,
          contentName: home[slot].contentName,
          items: home[slot].items,
          exercises: home[slot].exercises,
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
      routeSettings: const RouteSettings(name: 'lock_screen_meal_screen_showDialog_0'),
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
                      'ウィジェットでワンタップ記録です。ホーム画面の大きなウィジェットは、残りカロリーに加え、アプリを開かずに食事と運動を登録します。枠は食事と運動を自由に組み合わせられます。ロック画面の3枠は、ホームの1〜3枠目を種類も含めてそのまま使います。枠の中身は、保存した食事・運動テンプレートを選んで食品や種目ごとに量を変えて入れるか、その場で作ります。枠に入れても元のテンプレートは変わらず、テンプレートの件数にも入りません。',
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
                  _buttonCard(slot),
                ],
                const SizedBox(height: AppSpacing.md),
                Text('ロック画面', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'ロック画面の3枠は、ホームの1〜3枠目を種類も含めてそのまま使います。',
                  style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: AppSpacing.md),
                for (
                  var slot = 0;
                  slot < LockScreenMealConfig.lockSlotCount;
                  slot++
                ) ...[
                  if (slot > 0) const SizedBox(height: AppSpacing.sm),
                  ListenableBuilder(
                    listenable: _home.labels[slot],
                    builder: (context, _) {
                      return Text(
                        _lockPreviewLine(slot),
                        key: Key('lock-screen-meal-preview-$slot'),
                        style: AppTypography.bodyL,
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
              ],
            ),
    );
  }

  String _kindLabel(WidgetPatternKind kind) {
    return kind == WidgetPatternKind.exercise ? '運動' : '食事';
  }

  String _slotTitle(int slot) {
    return '枠${slot + 1}・${_kindLabel(_home.kinds[slot])}';
  }

  String _lockPreviewLine(int slot) {
    final label = _home.labels[slot].text.trim();
    final shown = label.isEmpty ? '文字なし' : label;
    return '枠${slot + 1} · ${_kindLabel(_home.kinds[slot])} · $shown';
  }

  Widget _buttonCard(int slot) {
    final exercise = _home.kinds[slot] == WidgetPatternKind.exercise;
    final summary = exercise
        ? _exerciseSummary(_home.exercises[slot])
        : _mealSummary(_home.items[slot]);
    final assigned = summary != null;
    return DesignFieldCard(
      key: Key('widget-slot-card-$slot'),
      icon: _icon(exercise ? AppIcons.exercise : AppIcons.meal),
      label: _slotTitle(slot),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ChoiceChip(
                key: Key('widget-slot-kind-$slot-meal'),
                label: const Text('食事'),
                selected: !exercise,
                onSelected: (_) => _setKind(slot, WidgetPatternKind.meal),
              ),
              const SizedBox(width: AppSpacing.sm),
              ChoiceChip(
                key: Key('widget-slot-kind-$slot-exercise'),
                label: const Text('運動'),
                selected: exercise,
                onSelected: (_) => _setKind(slot, WidgetPatternKind.exercise),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _templatePicker(slot, exercise),
          const SizedBox(height: AppSpacing.md),
          DesignInputBox(
            child: DesignTextInput(
              key: Key('lock-screen-meal-label-home-$slot'),
              controller: _home.labels[slot],
              hintText: '表示する文字',
              inputFormatters: [LengthLimitingTextInputFormatter(8)],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignInputBox(
            key: Key('lock-screen-meal-template-home-$slot'),
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

  /// 保存したテンプレートのプルダウン。選ぶと量の入力へ進む。
  Widget _templatePicker(int slot, bool exercise) {
    final options = exercise
        ? [
            for (final template in _workoutTemplates)
              (template.templateId, template.name),
          ]
        : [
            for (final template in _mealTemplates)
              (template.templateId, template.name),
          ];
    final empty = options.isEmpty;
    return DropdownButtonFormField<String>(
      key: Key('widget-slot-template-$slot-${exercise ? 'exercise' : 'meal'}'),
      initialValue: null,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: exercise ? '運動テンプレートから選ぶ' : '食事テンプレートから選ぶ',
        border: const OutlineInputBorder(),
      ),
      hint: Text(
        empty ? '保存したテンプレートはまだありません' : 'テンプレートを選ぶ',
        style: AppTypography.bodyM.copyWith(color: AppColors.textMuted),
      ),
      items: [
        for (final option in options)
          DropdownMenuItem<String>(
            value: option.$1,
            child: Text(option.$2, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: empty
          ? null
          : (id) {
              if (id == null) {
                return;
              }
              if (exercise) {
                _pickWorkoutTemplate(slot, id);
              } else {
                _pickMealTemplate(slot, id);
              }
            },
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
