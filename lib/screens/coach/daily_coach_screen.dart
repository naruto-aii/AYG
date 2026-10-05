import 'package:flutter/material.dart';

import '../../repositories/coach_intro_store.dart';
import '../../repositories/coach_nutrition_source.dart';
import '../../repositories/coach_proposal_log.dart';
import '../../services/daily_coach.dart';
import '../../services/daily_coach_session.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
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
  });

  final AppController? controller;
  final Future<DailyCoachLoadResult> Function()? load;
  final Future<void> Function(CoachMealProposal proposal, List<double> grams)?
  onSelectMeal;
  final Future<void> Function(CoachExerciseProposal proposal, double amount)?
  onSelectExercise;
  final CoachNutritionSource? nutritionSource;
  final DateTime? now;
  final CoachIntroStore? introStore;
  final CoachProposalLog? proposalLog;

  @override
  State<DailyCoachScreen> createState() => _DailyCoachScreenState();
}

class _DailyCoachScreenState extends State<DailyCoachScreen> {
  DailyCoachLoadResult? _result;
  bool _saving = false;
  List<CoachProposalRecord> _shown = const [];
  Future<void> _recorded = Future<void>.value();
  final Map<String, TextEditingController> _amounts = {};

  CoachProposalLog get _log {
    return widget.proposalLog ??
        widget.controller?.coachProposalLog ??
        const NoOpCoachProposalLog();
  }

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowIntro();
    });
  }

  @override
  void dispose() {
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
      for (final indexed in result.meals.indexed) {
        for (
          var component = 0;
          component < indexed.$2.components.length;
          component++
        ) {
          final grams = indexed.$2.components[component].grams;
          _amounts['${indexed.$1}-$component'] = TextEditingController(
            text: formatCoachAmount(grams.toDouble()),
          );
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

  Future<void> _maybeShowIntro() async {
    final store = widget.introStore ?? PreferencesCoachIntroStore();
    final seen = await store.hasSeen();
    if (!mounted || seen) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text(coachTrialNotice),
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
    }
    _bindAmounts(result);
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
        final select = widget.onSelectMeal;
        if (select != null) {
          await select(proposal, grams);
          return;
        }
        final controller = widget.controller;
        if (controller == null) {
          throw StateError('coach');
        }
        await DailyCoachSession(
          controller: controller,
        ).saveMeal(proposal, grams: grams);
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
          const DesignTitleBlock(title: '今日のコーチ', showBack: false),
          if (result == null)
            Text('提案を作っています', style: AppTypography.bodyS)
          else if (result.status == DailyCoachStatus.nutritionMissing)
            Text(coachNutritionMissingMessage, style: AppTypography.bodyS)
          else ...[
            if (result.offersExercise) _exerciseCard(result),
            if (result.offersMeals) ...[
              Text('食事の案', style: AppTypography.titleM),
              for (final indexed in result.meals.indexed)
                _mealCard(indexed.$2, indexed.$1),
            ],
          ],
          const SizedBox(height: 16),
          const DesignCard(
            key: Key('coach_verification_notice'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '残りのカロリーから、今日の食事か運動を一つ提案します。登録するまでは記録されません。',
                  style: AppTypography.bodyS,
                ),
                SizedBox(height: 8),
                Text(coachTrialNotice, style: AppTypography.bodyS),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _exerciseCard(DailyCoachLoadResult result) {
    final proposal = result.exercise;
    final message = proposal?.message ?? result.exerciseMessage ?? '';
    return DesignCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTypography.bodyS),
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

  Widget _mealCard(CoachMealProposal meal, int index) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DesignCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(meal.headline, style: AppTypography.titleM),
            const SizedBox(height: 4),
            Text(
              '約${meal.kcal.round()}kcal',
              style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
            ),
            if (meal.macroNote != null) ...[
              const SizedBox(height: 4),
              Text(meal.macroNote!, style: AppTypography.bodyS),
            ],
            const SizedBox(height: 12),
            for (
              var component = 0;
              component < meal.components.length;
              component++
            ) ...[
              Text(
                meal.components[component].displayName,
                style: AppTypography.labelM,
              ),
              const SizedBox(height: 6),
              DesignInputBox(
                suffix: 'g',
                child: DesignTextInput(
                  controller: _amounts['$index-$component']!,
                  inputKey: Key('coach_meal_grams_${index}_$component'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
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
    );
  }
}
