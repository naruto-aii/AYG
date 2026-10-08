import 'package:flutter/material.dart';

import '../../models/daily_summary.dart';
import '../../repositories/coach_slot_store.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../services/analytics/catalog_actions.dart';
import '../../services/cook_coach.dart';
import '../../services/cook_coach_client.dart';
import '../../services/cook_coach_target.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../utils/meal_slot.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';
import '../subscription/calonavi_plus_flow.dart';

const cookCoachIngredientChoices = [
  '卵',
  'ごはん',
  '鶏むね肉',
  '豚こま切れ',
  '豆腐',
  '玉ねぎ',
  'にんじん',
  'じゃがいも',
  'キャベツ',
  'トマト',
  'ねぎ',
  '鮭',
  '納豆',
  '牛乳',
  'もやし',
  'ほうれん草',
];

const cookCoachTimeChoices = ['10分', '15分', '20分', '30分'];

/// 手元の食材から、この食事の目標に近い自炊を2案出す。
class CookCoachScreen extends StatefulWidget {
  const CookCoachScreen({
    super.key,
    this.controller,
    this.now,
    this.client,
    this.target,
    this.avoid = const [],
    this.onRegister,
    this.slotStore,
    this.skipSlots = const {},
  });

  final AppController? controller;
  final DateTime? now;
  final CookCoachClient? client;

  /// テストが目標を渡す。無ければ今日の残りから計算する。
  final CookCoachMealTarget? target;

  /// プロフィールにアレルギーや苦手があれば渡す。無いときは空。
  final List<String> avoid;

  final Future<List<String>> Function(CookDish dish, MealSlot slot)? onRegister;
  final CoachSlotStore? slotStore;
  final Set<MealSlot> skipSlots;

  @override
  State<CookCoachScreen> createState() => _CookCoachScreenState();
}

class _CookCoachScreenState extends State<CookCoachScreen> {
  late final TextEditingController _input = TextEditingController();
  late final FocusNode _inputFocus = FocusNode();
  late MealSlot _slot;
  final List<String> _ingredients = [];
  String? _note;
  bool _busy = false;
  String? _error;
  CookCoachResult? _result;
  CookDish? _saved;
  bool _opened = false;

  DateTime get _now => widget.now ?? DateTime.now();

  bool get _plusBlocked {
    final controller = widget.controller;
    if (controller == null) {
      return false;
    }
    return !controller.subscriptionRepository.isPlusActive;
  }

  CookCoachMealTarget get _target {
    final summary = widget.controller?.summary;
    if (summary != null) {
      return _targetFromSummary(summary);
    }
    final given = widget.target;
    if (given != null) {
      return cookCoachMealTarget(
        now: _now,
        slot: _slot,
        remainingKcal: given.remainingKcal,
        remainingProteinG: given.remainingProteinG > 0
            ? given.remainingProteinG
            : given.proteinG,
        remainingFatG: given.remainingFatG > 0 ? given.remainingFatG : given.fatG,
        remainingCarbG: given.remainingCarbG > 0
            ? given.remainingCarbG
            : given.carbG,
        skipSlots: widget.skipSlots,
      );
    }
    return _targetFromSummary(null);
  }

  @override
  void initState() {
    super.initState();
    _slot = widget.target?.slot ?? cookCoachDefaultSlot(_now);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_opened || !mounted || _plusBlocked) {
        return;
      }
      _opened = true;
      CatalogActions.cookCoachOpen(_slot.name);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  CookCoachMealTarget _targetFromSummary(DailySummary? summary) {
    return cookCoachMealTarget(
      now: _now,
      slot: _slot,
      remainingKcal: summary?.remainingKcal ?? 0,
      remainingProteinG: summary == null
          ? 0
          : summary.targetProteinG - summary.intakeProteinG,
      remainingFatG: summary == null
          ? 0
          : summary.targetFatG - summary.intakeFatG,
      remainingCarbG: summary == null
          ? 0
          : summary.targetCarbG - summary.intakeCarbG,
      skipSlots: widget.skipSlots,
    );
  }

  void _addFromField() {
    _addNames(cookIngredientNames(_input.text));
    _input.clear();
  }

  void _addNames(List<String> names) {
    if (names.isEmpty) {
      return;
    }
    setState(() {
      for (final name in names) {
        if (!_ingredients.contains(name) && _ingredients.length < 20) {
          _ingredients.add(name);
        }
      }
    });
  }

  Future<void> _generate() async {
    if (_busy || _ingredients.isEmpty) {
      return;
    }
    final target = _target;
    final blocked = _blockedMessage(target);
    if (blocked != null) {
      setState(() => _error = blocked);
      return;
    }
    final client = widget.client ?? CookCoachClient.supabase();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await client.generate(
        ingredients: List<String>.from(_ingredients),
        slot: _slot,
        target: target,
        note: _note ?? '',
        avoid: widget.avoid,
      );
      if (!mounted) {
        return;
      }
      final first = result.calls.isEmpty ? null : result.calls.first;
      CatalogActions.cookCoachGenerate(
        latencyMs: first?.latencyMs ?? 0,
        inputTokens: first?.inputTokens ?? 0,
        outputTokens: first?.outputTokens ?? 0,
        retried: result.retried,
        result: 'ok',
      );
      if (result.retried && result.calls.length > 1) {
        final second = result.calls[1];
        CatalogActions.cookCoachRetry(
          latencyMs: second.latencyMs,
          inputTokens: second.inputTokens,
          outputTokens: second.outputTokens,
        );
      }
      setState(() {
        _result = result;
        _busy = false;
      });
    } on CookCoachFailure catch (error) {
      if (!mounted) {
        return;
      }
      if (error.code == 'daily_cap' || error.message == cookCoachCapMessage) {
        CatalogActions.cookCoachCap();
      }
      CatalogActions.cookCoachGenerate(
        latencyMs: 0,
        inputTokens: 0,
        outputTokens: 0,
        retried: false,
        result: error.code ?? 'failed',
      );
      setState(() {
        _busy = false;
        _error = error.message;
      });
    }
  }

  Future<void> _register(CookDish dish) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final List<String> ids;
      final select = widget.onRegister;
      if (select != null) {
        ids = await select(dish, _slot);
      } else {
        final controller = widget.controller;
        if (controller == null) {
          throw StateError('cook');
        }
        ids = await saveCookCoachDish(
          controller: controller,
          dish: dish,
          loggedAt: DateTime.now(),
        );
      }
      final store = widget.slotStore;
      if (store != null) {
        await store.markRegistered(
          day: _now,
          slot: _slot,
          kcal: dish.kcal,
          entryIds: ids,
        );
      }
      CatalogActions.cookCoachRegister(
        foodEntryIds: ids,
        pattern: dish.kind,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _saved = dish;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _busy = false;
        _error = '食事に追加できませんでした';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final saved = _saved;
    final showingResults = _result != null && saved == null;
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: showingResults ? 2 : 14),
          Align(
            alignment: Alignment.centerLeft,
            child: DesignBackButton(
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Text(
            '自炊コーチ (β)',
            key: const Key('cook_coach_title'),
            style: AppTypography.headingL,
          ),
          if (_result == null) ...[
            const SizedBox(height: 8),
            Text(
              '手元の食材と、この食事の目標から作る料理を2案出します。',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 2),
          if (_plusBlocked)
            _plusGate()
          else if (saved != null)
            _savedBody(saved)
          else ...[
            _targetLine(),
            if (_blockedMessage(_target) != null) ...[
              const SizedBox(height: 8),
              Text(
                _blockedMessage(_target)!,
                key: const Key('cook_blocked'),
                style: AppTypography.bodyS,
              ),
            ],
            SizedBox(height: showingResults ? 4 : 12),
            if (_result == null) _form() else _results(_result!),
          ],
        ],
      ),
    );
  }

  Widget _plusGate() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DesignCard(
          child: Text(
            '自炊コーチ (β) は、カロナビ+です。手元の食材から、この食事の目標に近い料理を出します。',
            style: AppTypography.bodyS,
          ),
        ),
        const SizedBox(height: 16),
        DesignButton(
          label: 'カロナビ+を見る',
          showTrailingIcon: false,
          onPressed: () {
            final controller = widget.controller;
            if (controller == null) {
              return;
            }
            controller.recordPlusFunnel(
              event: PlusFunnelEvent.gateTap,
              feature: PlusFunnelFeature.coach,
            );
            final custom = controller.openCalonaviPlusFlow;
            if (custom != null) {
              custom(context);
              return;
            }
            showCalonaviPlus(
              context,
              repository: controller.subscriptionRepository,
              feature: PlusFunnelFeature.coach,
              funnel: controller.plusFunnelRepository,
            );
          },
        ),
      ],
    );
  }

  Widget _targetLine() {
    final target = _target;
    final kcal = target.kcal.round();
    return Text(
      '${_slot.label}の目標 ${kcal}kcal'
      '（P ${target.proteinG.round()}g / F ${target.fatG.round()}g / C ${target.carbG.round()}g）',
      key: const Key('cook_target'),
      style: AppTypography.titleM,
    );
  }

  String? _blockedMessage(CookCoachMealTarget target) {
    if (target.remainingKcal <= 0) {
      return '今日の目標は、もう足りています。';
    }
    if (!target.canGenerate) {
      return 'この食事の目標が少ないため、献立は作れません。';
    }
    return null;
  }

  Widget _form() {
    final target = _target;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('食事', style: AppTypography.titleM),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slot in MealSlot.displayOrder)
              _choice(
                key: Key('cook_slot_${slot.name}'),
                label: slot.label,
                selected: _slot == slot,
                onTap: () => setState(() => _slot = slot),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text('手元の食材', style: AppTypography.titleM),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in cookCoachIngredientChoices)
              _choice(
                key: Key('cook_choice_$name'),
                label: name,
                selected: _ingredients.contains(name),
                onTap: () {
                  setState(() {
                    if (_ingredients.contains(name)) {
                      _ingredients.remove(name);
                    } else {
                      _ingredients.add(name);
                    }
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        DesignInputBox(
          trailing: IconButton(
            key: const Key('cook_voice'),
            tooltip: '音声入力',
            onPressed: () => _inputFocus.requestFocus(),
            icon: const DesignIcon(
              Symbols.mic_rounded,
              size: 22,
              color: AppColors.iconMuted,
            ),
          ),
          child: DesignTextInput(
            controller: _input,
            focusNode: _inputFocus,
            inputKey: const Key('cook_ingredient_input'),
            hintText: '食材を入力。複数は、で区切る',
          ),
        ),
        const SizedBox(height: 8),
        DesignButton(
          key: const Key('cook_add_ingredient'),
          label: '食材を追加',
          height: 48,
          style: DesignButtonStyle.secondary,
          showTrailingIcon: false,
          onPressed: _addFromField,
        ),
        if (_ingredients.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final name in _ingredients)
                _choice(
                  key: Key('cook_selected_$name'),
                  label: name,
                  selected: true,
                  onTap: () => setState(() => _ingredients.remove(name)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text('条件（任意）', style: AppTypography.titleM),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final note in cookCoachTimeChoices)
              _choice(
                key: Key('cook_note_$note'),
                label: note,
                selected: _note == note,
                onTap: () => setState(() {
                  _note = _note == note ? null : note;
                }),
              ),
          ],
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            key: const Key('cook_error'),
            style: AppTypography.bodyS,
          ),
        ],
        const SizedBox(height: 16),
        DesignButton(
          key: const Key('cook_generate'),
          label: _busy ? '作っています' : '2案を作る',
          height: 52,
          showTrailingIcon: false,
          loading: _busy,
          onPressed: _busy || _ingredients.isEmpty || _blockedMessage(target) != null
              ? null
              : _generate,
        ),
      ],
    );
  }

  Widget _results(CookCoachResult result) {
    if (result.patterns.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.emptyMessage,
            key: const Key('cook_empty'),
            style: AppTypography.bodyM,
          ),
          const SizedBox(height: 12),
          DesignButton(
            key: const Key('cook_back_to_input'),
            label: '食材を変える',
            height: 48,
            style: DesignButtonStyle.secondary,
            showTrailingIcon: false,
            onPressed: _busy ? null : () => setState(() => _result = null),
          ),
        ],
      );
    }
    final hasEstimate = result.patterns.any(
      (dish) => dish.ingredients.any((item) => !item.fromDatabase),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '合計は、材料の行を足した値です。',
          style: AppTypography.caption.copyWith(height: 1.15),
        ),
        if (hasEstimate)
          Text(
            '成分表に無い食品はAIの目安です。',
            key: const Key('cook_estimate_note'),
            style: AppTypography.caption.copyWith(height: 1.15),
          ),
        for (final dish in result.patterns) ...[
          const SizedBox(height: 12),
          _dishCard(dish),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, key: const Key('cook_error'), style: AppTypography.bodyS),
        ],
        const SizedBox(height: 12),
        DesignButton(
          key: const Key('cook_back_to_input'),
          label: '食材を変える',
          height: 48,
          style: DesignButtonStyle.secondary,
          showTrailingIcon: false,
          onPressed: _busy ? null : () => setState(() => _result = null),
        ),
      ],
    );
  }

  Widget _dishCard(CookDish dish) {
    final onHand = dish.kind != 'extra';
    final title = onHand ? '手持ちだけで作れます' : '買い足しで作れます';
    final line = AppTypography.bodyS.copyWith(
      color: AppColors.textPrimary,
      height: 1.35,
    );
    final emphasis = AppTypography.titleM.copyWith(height: 1.2);
    return DesignCard(
      key: Key('cook_pattern_${dish.kind}'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Text(dish.name, style: AppTypography.headingM),
          if (dish.minutes > 0) ...[
            const SizedBox(height: 4),
            Text('調理の目安 ${dish.minutes}分', style: AppTypography.titleM),
          ],
          if (dish.extras.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('買い足すもの: ${dish.extras.join('、')}', style: line),
          ],
          if (dish.omitNote.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(dish.omitNote, style: line),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text('材料', style: AppTypography.caption)),
              SizedBox(
                width: 88,
                child: Text('量', textAlign: TextAlign.right, style: AppTypography.caption),
              ),
              SizedBox(
                width: 64,
                child: Text('kcal', textAlign: TextAlign.right, style: AppTypography.caption),
              ),
            ],
          ),
          for (final item in dish.ingredients) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.assumed
                        ? '${item.name}（家にあるもの）'
                        : item.extra
                        ? '${item.name}（買い足し）'
                        : item.name,
                    key: Key('cook_ingredient_${dish.kind}_${item.name}'),
                    style: line,
                  ),
                ),
                SizedBox(
                  width: 88,
                  child: Text(
                    _cookAmount(item.name, item.grams),
                    textAlign: TextAlign.right,
                    style: line,
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                    '${item.kcal}',
                    key: Key('cook_kcal_${dish.kind}_${item.name}'),
                    textAlign: TextAlign.right,
                    style: line,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          for (var i = 0; i < dish.steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            Text(
              '${i + 1}. ${dish.steps[i]}',
              style: line.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            '${dish.kcal}kcal　P ${dish.proteinG}g　F ${dish.fatG}g　C ${dish.carbG}g',
            key: Key('cook_totals_${dish.kind}'),
            style: emphasis,
          ),
          if (dish.withinTolerance)
            Text(
              '目標の範囲に入っています',
              key: Key('cook_within_${dish.kind}'),
              style: line.copyWith(color: AppColors.green800),
            ),
          Text(
            cookKcalGapLabel(dish.gapKcal),
            key: Key('cook_gap_${dish.kind}'),
            style: emphasis,
          ),
          Text(
            '${cookMacroGapLabel('P', dish.gapProteinG)}　'
            '${cookMacroGapLabel('F', dish.gapFatG)}　'
            '${cookMacroGapLabel('C', dish.gapCarbG)}',
            key: Key('cook_macro_gap_${dish.kind}'),
            style: line.copyWith(color: AppColors.textMuted),
          ),
          if (!dish.withinTolerance && dish.gapReason.isNotEmpty)
            Text(
              dish.gapReason,
              key: Key('cook_reason_${dish.kind}'),
              style: line,
            ),
          const SizedBox(height: 4),
          DesignButton(
            key: Key('cook_register_${dish.kind}'),
            label: 'これを作る',
            height: 32,
            showTrailingIcon: false,
            loading: _busy,
            onPressed: _busy ? null : () => _register(dish),
          ),
        ],
      ),
    );
  }

  Widget _savedBody(CookDish dish) {
    return Column(
      key: const Key('cook_saved'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('食事に追加しました', style: AppTypography.titleM),
        const SizedBox(height: 8),
        Text(dish.name, style: AppTypography.titleM),
        const SizedBox(height: 8),
        for (var i = 0; i < dish.ingredients.length; i++)
          Text(
            '${cookIngredientAmount(dish.ingredients[i].name, dish.ingredients[i].grams)}　${dish.ingredients[i].kcal}kcal',
            key: Key('cook_saved_${i}_${dish.ingredients[i].name}'),
            style: AppTypography.bodyS.copyWith(color: AppColors.textPrimary),
          ),
        const SizedBox(height: 8),
        Text(
          '${dish.kcal}kcal　P ${dish.proteinG}g　F ${dish.fatG}g　C ${dish.carbG}g',
          key: const Key('cook_saved_totals'),
          style: AppTypography.titleS,
        ),
        const SizedBox(height: 16),
        DesignButton(
          key: const Key('cook_close_saved'),
          label: '閉じる',
          height: 48,
          showTrailingIcon: false,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }

  Widget _choice({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: selected ? AppColors.bgPrimary : AppColors.bgSecondary,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: AppTypography.labelM.copyWith(
              color: selected ? AppColors.textOnPrimary : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

String _cookAmount(String name, int grams) {
  final full = cookIngredientAmount(name, grams);
  final split = full.indexOf(' ');
  return split < 0 ? full : full.substring(split + 1);
}
