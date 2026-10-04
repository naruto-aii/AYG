import 'package:flutter/material.dart';

import '../../services/daily_coach.dart';
import '../../services/daily_coach_session.dart';
import '../../state/app_controller.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import '../../repositories/coach_nutrition_source.dart';
import '../../widgets/design/design_card.dart';
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
  });

  final AppController? controller;
  final Future<DailyCoachLoadResult> Function()? load;
  final Future<void> Function(CoachMealProposal proposal)? onSelectMeal;
  final CoachNutritionSource? nutritionSource;
  final DateTime? now;

  @override
  State<DailyCoachScreen> createState() => _DailyCoachScreenState();
}

class _DailyCoachScreenState extends State<DailyCoachScreen> {
  DailyCoachLoadResult? _result;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
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
    setState(() => _result = result);
  }

  Future<void> _select(CoachMealProposal proposal) async {
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
          const DesignTitleBlock(title: '今日のコーチ'),
          const SizedBox(height: 8),
          const DesignCard(
            child: Text(coachTrialNotice, style: AppTypography.bodyS),
          ),
          const SizedBox(height: 8),
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
            for (final meal in result.meals) ...[
              const SizedBox(height: 8),
              DesignCard(
                onTap: _saving ? null : () => _select(meal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(meal.headline, style: AppTypography.titleM),
                    const SizedBox(height: 4),
                    Text(
                      '約${meal.kcal.round()}kcal',
                      style: AppTypography.bodyS.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (meal.macroNote != null) ...[
                      const SizedBox(height: 4),
                      Text(meal.macroNote!, style: AppTypography.bodyS),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
