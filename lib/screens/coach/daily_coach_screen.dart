import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../repositories/coach_intro_store.dart';
import '../../repositories/plus_funnel_repository.dart';
import '../../repositories/coach_nutrition_source.dart';
import '../../repositories/coach_proposal_log.dart';
import '../../repositories/coach_slot_store.dart';
import '../../services/analytics/catalog_actions.dart';
import 'cook_coach_screen.dart';
import '../../services/daily_coach.dart';
import '../../services/daily_coach_session.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../subscription/plus_gate.dart';
import '../weight/weight_record_screen.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_field.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';

/// ホームへ戻したときに、食事と運動のどちらを登録したか。
enum CoachSavedKind { meal, exercise }

/// ホームから開く、その日の提案。食事と運動は同時に出さない。
class DailyCoachScreen extends StatefulWidget {
  const DailyCoachScreen({
    super.key,
    this.controller,
    this.load,
    this.onSelectMeal,
    this.onSelectExercise,
    this.nutritionSource,
    this.now,
    this.introStore,
    this.proposalLog,
    this.slotStore,
  });

  final AppController? controller;
  final Future<DailyCoachLoadResult> Function()? load;
  final Future<List<String>> Function(
    CoachMealProposal proposal,
    List<double> grams,
  )?
  onSelectMeal;
  final Future<void> Function(CoachExerciseProposal proposal, double amount)?
  onSelectExercise;
  final CoachNutritionSource? nutritionSource;
  final DateTime? now;
  final CoachIntroStore? introStore;
  final CoachProposalLog? proposalLog;

  /// 1日の案で登録した枠。省略時は端末に保存する。
  final CoachSlotStore? slotStore;

  @override
  State<DailyCoachScreen> createState() => _DailyCoachScreenState();
}

class _DailyCoachScreenState extends State<DailyCoachScreen> {
  DailyCoachLoadResult? _result;
  bool _saving = false;
  List<CoachProposalRecord> _shown = const [];
  Future<void> _recorded = Future<void>.value();
  final Map<String, TextEditingController> _amounts = {};
  int _mealShift = 0;
  bool _wasPlusBlocked = false;
  StreamSubscription<bool>? _plusSubscription;

  late final CoachSlotStore _slotStore =
      widget.slotStore ?? PreferencesCoachSlotStore();

  CoachProposalLog get _log {
    return widget.proposalLog ??
        widget.controller?.coachProposalLog ??
        const NoOpCoachProposalLog();
  }

  bool get _plusBlocked {
    final controller = widget.controller;
    if (controller == null) {
      return false;
    }
    return !controller.subscriptionRepository.isPlusActive;
  }

  @override
  void initState() {
    super.initState();
    _wasPlusBlocked = _plusBlocked;
    _plusSubscription = widget.controller?.subscriptionRepository.plusChanges
        .listen(_onPlusChanged);
    if (_plusBlocked) {
      return;
    }
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowIntro();
    });
  }

  void _onPlusChanged(bool active) {
    if (!mounted) {
      return;
    }
    final blocked = !active;
    final opened = _wasPlusBlocked && !blocked;
    _wasPlusBlocked = blocked;
    if (!opened) {
      if (blocked) {
        setState(() {});
      }
      return;
    }
    setState(() => _result = null);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeShowIntro();
      }
    });
  }

  @override
  void dispose() {
    _plusSubscription?.cancel();
    _disposeAmounts();
    super.dispose();
  }

  void _disposeAmounts() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    _amounts.clear();
  }

  void _bindAmounts(DailyCoachLoadResult result) {
    _disposeAmounts();
    if (result.offersMeals) {
      final flat = [for (final plan in result.dayPlans) ...plan.meals];
      for (final indexed in flat.indexed) {
        for (
          var component = 0;
          component < indexed.$2.components.length;
          component++
        ) {
          final grams = indexed.$2.components[component].grams;
          // 量を変えたら、食品・食事・合計の kcal をその場で変える。
          _amounts['${indexed.$1}-$component'] = TextEditingController(
            text: formatCoachAmount(grams.toDouble()),
          )..addListener(_onAmountChanged);
        }
      }
    }
    final exercise = result.exercise;
    if (result.offersExercise &&
        exercise != null &&
        exercise.canRegister &&
        exercise.amount != null) {
      _amounts['exercise'] = TextEditingController(
        text: formatCoachAmount(exercise.amount!),
      );
    }
  }

  void _onAmountChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _maybeShowIntro() async {
    final store = widget.introStore ?? PreferencesCoachIntroStore();
    final seen = await store.hasSeen();
    if (!mounted || seen) {
      return;
    }
    await showDialog<void>(
      routeSettings: const RouteSettings(
        name: 'daily_coach_screen_showDialog_0',
      ),
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(AppStrings.coachFeatureBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
    await store.markSeen();
  }

  void _close() {
    Navigator.of(context).maybePop();
  }

  Future<DailyCoachLoadResult> _defaultLoad() {
    final controller = widget.controller;
    if (controller == null) {
      return Future.value(
        const DailyCoachLoadResult(status: DailyCoachStatus.nutritionMissing),
      );
    }
    return DailyCoachSession(
      controller: controller,
      nutritionSource: widget.nutritionSource,
      slotStore: _slotStore,
    ).load(widget.now ?? DateTime.now());
  }

  Future<void> _load() async {
    final result = await (widget.load ?? _defaultLoad)();
    if (!mounted) {
      return;
    }
    if (result.status == DailyCoachStatus.ready) {
      _shown = coachProposalRecords(
        now: widget.now ?? DateTime.now(),
        result: result,
      );
      _recorded = _log.recordShown(_shown);
      CatalogActions.coachProposalShown(
        coachProposalLogId: 'local',
        proposalsCount: _shown.length,
      );
    }
    _bindAmounts(result);
    _mealShift = 0;
    setState(() => _result = result);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _commit({
    required CoachSavedKind kind,
    required int index,
    required String failure,
    required Future<void> Function() action,
  }) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      await action();
      if (index >= 0 && index < _shown.length) {
        final shownId = _shown[index].id;
        try {
          await _recorded;
          await _log.markRegistered(id: shownId);
        } catch (_) {}
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(kind);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _snack(failure);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  List<double>? _mealGrams(CoachMealProposal proposal, int index) {
    final grams = <double>[];
    for (
      var component = 0;
      component < proposal.components.length;
      component++
    ) {
      final parsed = parseCoachAmount(
        _amounts['$index-$component']?.text ?? '',
      );
      if (parsed == null) {
        return null;
      }
      grams.add(parsed);
    }
    return grams;
  }

  Future<void> _registerMeal(CoachMealProposal proposal, int index) async {
    final grams = _mealGrams(proposal, index);
    if (grams == null) {
      _snack('量は0より大きい数字にしてください');
      return;
    }
    await _commit(
      kind: CoachSavedKind.meal,
      index: index,
      failure: '食事に追加できませんでした',
      action: () async {
        final List<String> ids;
        final select = widget.onSelectMeal;
        if (select != null) {
          ids = await select(proposal, grams);
        } else {
          final controller = widget.controller;
          if (controller == null) {
            throw StateError('coach');
          }
          ids = await DailyCoachSession(
            controller: controller,
          ).saveMeal(proposal, grams: grams);
        }
        // 登録した枠は、開き直したときの案から外す（新しい残りで、まだの枠だけを組み直す）。
        final slot = proposal.slot;
        if (slot != null) {
          await _slotStore.markRegistered(
            day: widget.now ?? DateTime.now(),
            slot: slot,
            kcal: _mealKcal(proposal, index),
            entryIds: ids,
          );
        }
        final logId = index >= 0 && index < _shown.length
            ? _shown[index].id
            : 'local';
        CatalogActions.coachProposalRegistered(
          coachProposalLogId: logId,
          foodEntryIds: ids,
        );
      },
    );
  }

  Future<void> _registerExercise(CoachExerciseProposal proposal) async {
    final amount = parseCoachAmount(_amounts['exercise']?.text ?? '');
    if (amount == null) {
      _snack('量は0より大きい数字にしてください');
      return;
    }
    if (proposal.unit == CoachExerciseUnit.minutes &&
        coachWholeMinutes(amount) == null) {
      _snack('分は1以上の整数にしてください');
      return;
    }
    await _commit(
      kind: CoachSavedKind.exercise,
      index: 0,
      failure: '運動に追加できませんでした',
      action: () async {
        final select = widget.onSelectExercise;
        if (select != null) {
          await select(proposal, amount);
          return;
        }
        final controller = widget.controller;
        if (controller == null) {
          throw StateError('coach');
        }
        final saved = await DailyCoachSession(
          controller: controller,
        ).saveExercise(proposal, amount: amount);
        if (!saved) {
          throw StateError('coach exercise');
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 14),
          Row(
            children: [
              DesignBackButton(onPressed: _close),
              const Spacer(),
              IconButton(
                tooltip: '閉じる',
                onPressed: _close,
                icon: const DesignIcon(
                  Symbols.close_rounded,
                  size: 22,
                  color: AppColors.iconMuted,
                ),
              ),
            ],
          ),
          const DesignTitleBlock(title: 'パーソナルコーチ (β)', showBack: false),
          if (!_plusBlocked) ...[
            CookCoachEntryButton(
              key: const Key('cook_coach_entry'),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    settings: const RouteSettings(name: 'cook_coach'),
                    builder: (context) => CookCoachScreen(
                      controller: widget.controller,
                      now: widget.now,
                      slotStore: _slotStore,
                    ),
                  ),
                );
                if (saved == true && context.mounted) {
                  Navigator.of(context).pop(CoachSavedKind.meal);
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          if (_plusBlocked) ...[
            const DesignCard(
              key: Key('coach_beta_notice'),
              child: Text(
                AppStrings.coachBetaNotice,
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
                ensureCalonaviPlus(
                  context,
                  controller,
                  message: AppStrings.coachBetaNotice,
                  feature: PlusFunnelFeature.coach,
                );
              },
            ),
          ] else if (result == null)
            Text('提案を作っています', style: AppTypography.bodyS)
          else if (result.status == DailyCoachStatus.nutritionMissing)
            Text(coachNutritionMissingMessage, style: AppTypography.bodyS)
          else ...[
            if (result.message != null)
              Text(result.message!, style: AppTypography.bodyS),
            if (result.offersExercise) _exerciseCard(result),
            if (result.offersMeals) ...[
              if (result.plans.isEmpty)
                Text('食事の案', style: AppTypography.titleM),
              _visibleMeal(result),
            ],
          ],
          const SizedBox(height: 16),
          if (!_plusBlocked)
            const DesignCard(
              key: Key('coach_beta_notice'),
              child: Text(
                AppStrings.coachFeatureBody,
                style: AppTypography.bodyS,
              ),
            ),
        ],
      ),
    );
  }

  Widget _visibleMeal(DailyCoachLoadResult result) {
    final plans = result.dayPlans;
    final count = plans.length;
    final now = widget.now ?? DateTime.now();
    final day = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(now.year)).inDays;
    final shown = count == 0 ? 0 : (day + _mealShift) % count;
    final plan = plans[shown];
    // 画面と記録で共通の通し番号。前の案の回数を足す。
    var offset = 0;
    for (var i = 0; i < shown; i++) {
      offset += plans[i].meals.length;
    }
    final daySummary = result.plans.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (daySummary)
          _daySummary(result, plan, offset)
        else if (plan.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(plan.note!, style: AppTypography.bodyS),
          ),
        if (count > 1) ...[
          const SizedBox(height: 8),
          DesignButton(
            key: const Key('coach_other_proposal'),
            label: 'ほかの案',
            height: 48,
            style: DesignButtonStyle.secondary,
            showTrailingIcon: false,
            onPressed: () => setState(() => _mealShift++),
          ),
        ],
        for (var m = 0; m < plan.meals.length; m++)
          _mealSection(
            plan.meals[m],
            offset + m,
            _numberedLabel(plan.meals, m),
          ),
      ],
    );
  }

  /// 今日の残りに対して、どの食事で何kcal食べ、合計がいくつになるか。
  Widget _daySummary(
    DailyCoachLoadResult result,
    CoachDayPlan plan,
    int offset,
  ) {
    final remaining = plan.remainingKcal.round();
    var total = 0;
    for (var m = 0; m < plan.meals.length; m++) {
      total += _mealKcal(plan.meals[m], offset + m);
    }
    final percent = remaining <= 0 ? 0 : (total / remaining * 100).round();
    final muted = AppTypography.bodyM.copyWith(color: AppColors.textMuted);
    return DesignCard(
      key: const Key('coach_day_summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '今日の残り ${formatCoachKcal(remaining)}kcal の食べ方',
            key: const Key('coach_day_summary_title'),
            style: AppTypography.titleM,
          ),
          const SizedBox(height: 4),
          Text(
            'おすすめの量で食べたときのカロリーです。',
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          for (final item in result.registered)
            _summaryRow(
              item.slot.label,
              '登録済み ${formatCoachKcal(item.kcal)}kcal',
              key: Key('coach_summary_registered_${item.slot.name}'),
              style: muted,
            ),
          for (var m = 0; m < plan.meals.length; m++)
            _summaryRow(
              _numberedLabel(plan.meals, m),
              '${formatCoachKcal(_mealKcal(plan.meals[m], offset + m))}kcal',
              key: Key('coach_summary_row_${offset + m}'),
              style: AppTypography.bodyM.copyWith(color: AppColors.textPrimary),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.neutral200),
          ),
          _summaryRow(
            '合計',
            '${formatCoachKcal(total)}kcal（残りの$percent%）',
            key: const Key('coach_day_total'),
            style: AppTypography.titleS,
          ),
          if (plan.note != null) ...[
            const SizedBox(height: 8),
            Text(
              plan.note!,
              key: const Key('coach_day_note'),
              style: AppTypography.bodyS,
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    required Key key,
    required TextStyle style,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 12),
          Text(value, style: style, textAlign: TextAlign.right),
        ],
      ),
    );
  }

  /// 同じ枠が2回あるとき（22時以降の間食2つ）は「間食 1」「間食 2」と番号を付ける。
  String _numberedLabel(List<CoachMealProposal> meals, int index) {
    final label = _mealLabel(meals[index]) ?? '食事';
    final same = [
      for (var i = 0; i < meals.length; i++)
        if ((_mealLabel(meals[i]) ?? '食事') == label) i,
    ];
    if (same.length < 2) {
      return label;
    }
    return '$label ${same.indexOf(index) + 1}';
  }

  /// 1日の案では枠（朝食・昼食・間食・夕食）。枠の無い1回分の案（旧形式）だけ量の区分。
  String? _mealLabel(CoachMealProposal meal) {
    return meal.slotLabel ?? meal.bandLabel;
  }

  /// 入っている量での、食品1つの kcal。数字でなければ null。
  int? _componentKcal(CoachMealProposal meal, int index, int component) {
    final item = meal.components[component];
    final edited = parseCoachAmount(_amounts['$index-$component']?.text ?? '');
    if (edited == null || item.grams <= 0) {
      return null;
    }
    final kcal = item.kcalPerUnit * item.units * edited / item.grams;
    if (!kcal.isFinite) {
      return null;
    }
    return (kcal + 1e-9).round();
  }

  /// 入っている量での、食事1回の kcal（食品ごとの kcal の合計）。
  int _mealKcal(CoachMealProposal meal, int index) {
    var total = 0;
    for (var component = 0; component < meal.components.length; component++) {
      total += _componentKcal(meal, index, component) ?? 0;
    }
    return total;
  }

  Widget _exerciseCard(DailyCoachLoadResult result) {
    final proposal = result.exercise;
    final message = proposal?.message ?? result.exerciseMessage ?? '';
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTypography.bodyS),
          if (proposal != null && proposal.needsWeight) ...[
            const SizedBox(height: 12),
            DesignButton(
              key: const Key('coach_register_weight'),
              label: '体重を登録',
              height: 48,
              showTrailingIcon: false,
              onPressed: widget.controller == null
                  ? null
                  : () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          settings: const RouteSettings(
                            name: 'daily_coach_screen_MaterialPageRoute_0',
                          ),
                          builder: (context) => WeightRecordScreen(
                            controller: widget.controller!,
                          ),
                        ),
                      );
                    },
            ),
          ],
          if (proposal != null && proposal.canRegister) ...[
            const SizedBox(height: 12),
            Text('登録する量', style: AppTypography.labelM),
            const SizedBox(height: 6),
            DesignInputBox(
              suffix: proposal.unitLabel,
              child: DesignTextInput(
                controller: _amounts['exercise']!,
                inputKey: const Key('coach_exercise_amount'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            DesignButton(
              key: const Key('coach_register_exercise'),
              label: 'この量で登録',
              height: 48,
              showTrailingIcon: false,
              onPressed: _saving ? null : () => _registerExercise(proposal),
            ),
          ],
        ],
      ),
    );
  }

  /// 枠ごとの見出し（枠名と kcal）と、食品・おすすめの量・kcal、登録ボタン。
  Widget _mealSection(CoachMealProposal meal, int index, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  label,
                  key: Key('coach_meal_label_$index'),
                  style: AppTypography.titleM,
                ),
              ),
              Text(
                '${formatCoachKcal(_mealKcal(meal, index))}kcal',
                key: Key('coach_meal_kcal_$index'),
                style: AppTypography.titleM,
              ),
            ],
          ),
        ),
        DesignCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 枠の無い1回分の案（旧形式）は、食品と量の一覧を見出しに出す。
              if (meal.slotLabel == null) ...[
                Text(meal.headline, style: AppTypography.titleS),
                const SizedBox(height: 8),
              ],
              if (meal.macroNote != null) ...[
                Text(meal.macroNote!, style: AppTypography.bodyS),
                const SizedBox(height: 8),
              ],
              for (
                var component = 0;
                component < meal.components.length;
                component++
              )
                _foodRow(meal, index, component),
              const SizedBox(height: 4),
              DesignButton(
                key: Key('coach_register_meal_$index'),
                label: 'この量で登録',
                height: 48,
                showTrailingIcon: false,
                onPressed: _saving ? null : () => _registerMeal(meal, index),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _foodRow(CoachMealProposal meal, int index, int component) {
    final item = meal.components[component];
    final kcal = _componentKcal(meal, index, component);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.displayName, style: AppTypography.labelM),
          if (item.portionNote != null)
            Text(
              'おすすめ ${item.grams}g（${item.portionNote}）',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            )
          else
            Text(
              'おすすめ ${item.grams}g',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: DesignInputBox(
                  suffix: 'g',
                  child: DesignTextInput(
                    controller: _amounts['$index-$component']!,
                    inputKey: Key('coach_meal_grams_${index}_$component'),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 84,
                child: Text(
                  kcal == null ? '—' : '${formatCoachKcal(kcal)}kcal',
                  key: Key('coach_food_kcal_${index}_$component'),
                  style: AppTypography.bodyM,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// パーソナルコーチの上に置く、自炊コーチへの入口。
///
/// すぐ下の「今日の残りの食べ方」（白いカード）の見出しに見えないよう、
/// 塗りの緑・アイコン・右向きの矢印・影で、押して移る部品だと分かる形にする。
class CookCoachEntryButton extends StatelessWidget {
  const CookCoachEntryButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '自炊コーチ (β)',
      onTap: onPressed,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: [
            BoxShadow(
              color: AppColors.green900.withValues(alpha: 0.22),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: AppColors.bgPrimary,
          borderRadius: _radius,
          child: InkWell(
            borderRadius: _radius,
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.cream0.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const DesignIcon(
                      Symbols.skillet_rounded,
                      size: 26,
                      color: AppColors.iconOnPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '自炊コーチ (β)',
                      style: AppTypography.titleM.copyWith(
                        color: AppColors.textOnPrimary,
                      ),
                    ),
                  ),
                  const DesignIcon(
                    Symbols.chevron_right_rounded,
                    size: 28,
                    color: AppColors.iconOnPrimary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
