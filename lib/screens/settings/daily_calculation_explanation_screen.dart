import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../models/daily_summary.dart';
import '../../services/health_activity_excess.dart';
import '../../models/goal.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../utils/nutrition_format.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';
import '../../widgets/design/settings_row.dart';
import 'calculation_references_screen.dart';

/// ホームの「あと○kcal」と PFC の計算根拠。
class DailyCalculationExplanationScreen extends StatelessWidget {
  const DailyCalculationExplanationScreen({super.key, required this.summary});

  final DailySummary summary;

  @override
  Widget build(BuildContext context) {
    final energy = summary.energyBreakdown;
    final macro = summary.macroBreakdown;
    final remaining = summary.remainingBreakdown;

    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'この数値の計算根拠',
            subtitle: AppStrings.healthEstimateDisclaimer,
          ),
          if (energy?.unavailableReason != null) ...[
            DesignCard(
              child: Text(
                energy!.unavailableReason!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('カロリー根拠', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.sm),
                if (energy?.manualTargetsActive == true) ...[
                  Text(
                    '食事目標と PFC は手入力です。体重や残日数では上書きしません。'
                    '自動に戻すと、日次の式に戻ります。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _row(
                    '1日の食事目標',
                    '${formatNullableNutrient(energy!.goalFoodTargetKcal)} kcal',
                  ),
                ],
                if (energy?.weightSeries != null) ...[
                  _row('計算に使用', energy!.weightSeries!.selection.usageLabel),
                  if (energy.weightSeries!.selection.healthUpdateStoppedNote !=
                      null)
                    Text(
                      energy.weightSeries!.selection.healthUpdateStoppedNote!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (energy.weightSeries!.selection.staleRecordPrompt != null)
                    Text(
                      energy.weightSeries!.selection.staleRecordPrompt!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (energy.smoothedWeightKg != null)
                    _row(
                      '平滑した体重',
                      '${energy.smoothedWeightKg!.toStringAsFixed(1)} kg（半減期7日）',
                    ),
                  _row('計算の段階', energy.usesLandingFormula ? '着地の式' : '初期式'),
                ],
                if (energy != null &&
                    energy.canEstimateRee &&
                    !energy.manualTargetsActive) ...[
                  Text('基礎代謝（安静時エネルギー消費量の推定）', style: AppTypography.titleS),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Mifflin–St Jeor 式による推定安静時消費（REE）です。'
                    '実測の基礎代謝ではなく、年齢・身長・体重・性別区分から算出した推定値です。',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _row('年齢', '${energy.ageYears} 歳'),
                  _row('身長', '${energy.heightCm?.toStringAsFixed(1)} cm'),
                  _row('体重', '${energy.weightKg?.toStringAsFixed(1)} kg'),
                  _row('性別', energy.genderLabel),
                  _row(
                    '推定安静時消費（REE）',
                    '${formatNullableNutrient(energy.estimatedReeKcal)} kcal',
                  ),
                  _row('普段の生活活動', energy.lifestyleActivityLabel ?? '—'),
                  _row(
                    '生活活動係数',
                    energy.lifestyleActivityFactor?.toStringAsFixed(3) ?? '—',
                  ),
                  _row(
                    '推定維持カロリー',
                    '${formatNullableNutrient(energy.estimatedMaintenanceKcal)} kcal',
                  ),
                  _row('目標', _goalLabel(energy.goalType)),
                  if (energy.goalType != GoalType.maintain)
                    _row(
                      '目標補正',
                      '${formatNullableNutrient(energy.dailyGoalAdjustmentKcal)} kcal/日（アプリ既定）',
                    ),
                  _row(
                    '1日の食事目標',
                    '${formatNullableNutrient(energy.goalFoodTargetKcal)} kcal',
                  ),
                  if (energy.usesLandingFormula &&
                      energy.rawBalanceKcal != null)
                    _row(
                      '着地に必要な収支',
                      '${energy.rawBalanceKcal!.toStringAsFixed(0)} kcal/日',
                    ),
                  if (energy.speedCapKcal != null)
                    _row(
                      '速度の上限',
                      '${energy.speedCapKcal!.toStringAsFixed(0)} kcal/日',
                    ),
                  if (energy.floorKcal != null)
                    _row(
                      '食事の床',
                      '${energy.floorKcal!.toStringAsFixed(0)} kcal',
                    ),
                  if (energy.heldForStaleWeight)
                    const Text('体重が古いため、直前の食事目標を維持しています。'),
                  if (energy.dailyStepLimited)
                    const Text('前日の食事目標から 150 kcal を超えない範囲に収めています。'),
                  if (energy.guidance != null) Text(energy.guidance!.message),
                ],
                if (energy != null &&
                    !energy.canEstimateRee &&
                    !energy.manualTargetsActive) ...[
                  Text(
                    energy.unavailableReason ??
                        '推定安静時消費を算出できません（18歳未満、'
                            'または性別区分が未設定の場合など）。',
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (remaining != null) ...[
                  _row(
                    '当日の追加運動（net）',
                    '${formatNullableNutrient(remaining.exerciseNetKcal)} kcal',
                  ),
                  if (remaining.healthActivityExcessKcal > 0)
                    _row(
                      'Health の上乗せ',
                      '${formatNullableNutrient(remaining.healthActivityExcessKcal)} kcal',
                    ),
                  _row(
                    '食事摂取',
                    '${formatNullableNutrient(remaining.foodKcal)} kcal',
                  ),
                  _row(
                    'アルコール摂取',
                    '${formatNullableNutrient(remaining.alcoholKcal)} kcal',
                  ),
                  _row(
                    summary.isCalorieOverage ? '超過カロリー' : '残りカロリー',
                    summary.isCalorieOverage
                        ? '${summary.calorieOverageKcal.toStringAsFixed(0)} kcal超過'
                        : '${summary.remainingKcal.toStringAsFixed(0)} kcal',
                  ),
                ],
                _row('計算バージョン', energy?.version ?? '—'),
                _row(
                  '最終更新',
                  energy?.calculatedAt.toLocal().toString().substring(0, 16) ??
                      '—',
                ),
                if (energy?.healthActiveEnergyKcal != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _healthActivityNote(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (macro != null)
            DesignCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PFC根拠', style: AppTypography.titleM),
                  const SizedBox(height: AppSpacing.sm),
                  _row(
                    '基準体重',
                    '${macro.referenceWeightKg.toStringAsFixed(1)} kg',
                  ),
                  _row('たんぱく質 g/kg', macro.proteinGPerKg.toStringAsFixed(2)),
                  _row('たんぱく質の理由', macro.proteinReason),
                  _row(
                    '脂質比率',
                    '${(macro.fatEnergyRatio * 100).toStringAsFixed(0)}%（アプリ既定）',
                  ),
                  _row('脂質の理由', macro.fatReason),
                  const Text('炭水化物は残余配分'),
                  _row('たんぱく質', '${macro.proteinG.toStringAsFixed(1)} g'),
                  _row('脂質', '${macro.fatG.toStringAsFixed(1)} g'),
                  _row('炭水化物', '${macro.carbG.toStringAsFixed(1)} g'),
                  _row(
                    'AMDR参考（P/F/C %）',
                    '${macro.amdrProteinPercentRange.$1}-${macro.amdrProteinPercentRange.$2} / '
                        '${macro.amdrFatPercentRange.$1}-${macro.amdrFatPercentRange.$2} / '
                        '${macro.amdrCarbPercentRange.$1}-${macro.amdrCarbPercentRange.$2}',
                  ),
                  if (macro.amdrWarnings.isNotEmpty)
                    ...macro.amdrWarnings.map(
                      (w) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          w,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  _row('計算バージョン', macro.version),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          SettingsRow(
            icon: AppIcons.document,
            title: '参考文献・計算式の詳細',
            subtitle: '計算式の出典をまとめています',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'daily_calculation_explanation_screen_MaterialPageRoute_0'),
                  builder: (context) => const CalculationReferencesScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Figma: ラベル左・値右、下に細い区切り線。
  Widget _row(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: AppTypography.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.titleS,
            ),
          ),
        ],
      ),
    );
  }

  String _healthActivityNote() {
    final energy = summary.energyBreakdown!;
    final excess = summary.remainingBreakdown?.healthActivityExcessKcal ?? 0;
    final above = const HealthActivityExcess().lifestyleAboveBasalKcal(
      basalReeKcal: energy.estimatedReeKcal,
      lifestyleFactor: energy.lifestyleActivityFactor,
    );
    final active = energy.healthActiveEnergyKcal!;
    final aboveText = above == null
        ? '算出できない'
        : '${above.toStringAsFixed(0)} kcal';
    return 'Health の当日アクティブエネルギー ${active.toStringAsFixed(0)} kcal。'
        '朝の基礎（REE）から見た生活活動分は $aboveText。'
        '超えた ${excess.toStringAsFixed(0)} kcal を画面の消費に足す。'
        '食事目標には足さない（${HealthActivityExcess.version}）。';
  }

  String _goalLabel(GoalType? goalType) {
    return switch (goalType) {
      GoalType.lose => '減量',
      GoalType.gain => '増量',
      GoalType.maintain || null => '維持',
    };
  }
}
