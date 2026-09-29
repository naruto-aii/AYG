import 'package:flutter/material.dart';

import '../../models/daily_summary.dart';
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
            subtitle:
                '表示されるカロリー・栄養素・運動消費量は一般的な式に基づく推定値です。'
                '医療上の診断や治療を目的としたものではありません。',
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
                if (energy != null && energy.canEstimateRee) ...[
                  Text(
                    '基礎代謝（安静時エネルギー消費量の推定）',
                    style: AppTypography.titleS,
                  ),
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
                    _row('目標ペース', energy.goalPace.labelJa),
                  if (energy.goalType != GoalType.maintain)
                    _row(
                      '目標補正',
                      '${formatNullableNutrient(energy.dailyGoalAdjustmentKcal)} kcal/日（アプリ既定）',
                    ),
                  _row(
                    '1日の食事目標',
                    '${formatNullableNutrient(energy.goalFoodTargetKcal)} kcal',
                  ),
                ],
                if (energy != null && !energy.canEstimateRee) ...[
                  Text(
                    energy.unavailableReason ??
                        '推定安静時消費を算出できません（18歳未満、'
                            'または性別区分が未設定の場合など）。',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
                if (remaining != null) ...[
                  _row(
                    '当日の追加運動（net）',
                    '${formatNullableNutrient(remaining.exerciseNetKcal)} kcal',
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
                    'Health の当日消費 ${energy!.healthActiveEnergyKcal!.toStringAsFixed(0)} kcal は参考表示です。'
                    '食事目標への加算には使いません（運動の二重計上防止）。',
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

  String _goalLabel(GoalType? goalType) {
    return switch (goalType) {
      GoalType.lose => '減量',
      GoalType.gain => '増量',
      GoalType.maintain || null => '維持',
    };
  }
}
