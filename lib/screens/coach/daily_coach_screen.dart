import 'package:flutter/material.dart';

import '../../repositories/coach_intro_store.dart';
import '../../repositories/coach_nutrition_source.dart';
import '../../repositories/coach_proposal_log.dart';
import '../../services/daily_coach.dart';
import '../../services/daily_coach_session.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_icon.dart';
import '../../widgets/design/design_page.dart';

/// ホームから開く、その日の食事と運動の提案。
class DailyCoachScreen extends StatefulWidget {
  const DailyCoachScreen({
    super.key,
    this.controller,
    this.load,
    this.onSelectMeal,
    this.nutritionSource,
    this.now,
    this.introStore,
    this.proposalLog,
  });

  final AppController? controller;
  final Future<DailyCoachLoadResult> Function()? load;
  final Future<void> Function(CoachMealProposal proposal)? onSelectMeal;
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
    setState(() => _result = result);
  }

  Future<void> _select(CoachMealProposal proposal, int index) async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final select = widget.onSelectMeal;
      if (select != null) {
        await select(proposal);
      } else {
        final controller = widget.controller;
        if (controller == null) {
          return;
        }
        await DailyCoachSession(controller: controller).save(proposal);
      }
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
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('食事に追加できませんでした')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
            if (result.exerciseMessage != null) ...[
              DesignCard(
                child: Text(
                  result.exerciseMessage!,
                  style: AppTypography.bodyS,
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (result.meals.isNotEmpty)
              Text('食事の案', style: AppTypography.titleM),
            for (final indexed in result.meals.indexed) ...[
              const SizedBox(height: 8),
              DesignCard(
                onTap: _saving ? null : () => _select(indexed.$2, indexed.$1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(indexed.$2.headline, style: AppTypography.titleM),
                    const SizedBox(height: 4),
                    Text(
                      '約${indexed.$2.kcal.round()}kcal',
                      style: AppTypography.bodyS.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (indexed.$2.macroNote != null) ...[
                      const SizedBox(height: 4),
                      Text(indexed.$2.macroNote!, style: AppTypography.bodyS),
                    ],
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          const DesignCard(
            key: Key('coach_verification_notice'),
            child: Text(coachTrialNotice, style: AppTypography.bodyS),
          ),
        ],
      ),
    );
  }
}
