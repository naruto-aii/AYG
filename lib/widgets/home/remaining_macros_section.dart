import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_text_styles.dart';

class RemainingKcalHero extends StatelessWidget {
  const RemainingKcalHero({super.key, required this.remainingKcal});

  final double remainingKcal;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onHero = colorScheme.onPrimaryContainer;

    return Card(
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          children: [
            Text('あと', style: AppTextStyles.heroLabel(context, onHero)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${remainingKcal.toStringAsFixed(0)} kcal',
              style: AppTextStyles.heroValue(context, onHero),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '食べられます',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: onHero),
            ),
          ],
        ),
      ),
    );
  }
}

class RemainingMacrosSection extends StatelessWidget {
  const RemainingMacrosSection({
    super.key,
    required this.remainingProteinG,
    required this.remainingCarbG,
    required this.remainingFatG,
  });

  final double remainingProteinG;
  final double remainingCarbG;
  final double remainingFatG;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('今日あと', style: AppTextStyles.sectionTitle(context)),
            const SizedBox(height: AppSpacing.md),
            _MacroRow(
              label: 'Protein',
              valueG: remainingProteinG,
              color: AppColors.macroProtein,
            ),
            const SizedBox(height: AppSpacing.xs),
            _MacroRow(
              label: 'Carb',
              valueG: remainingCarbG,
              color: AppColors.macroCarb,
            ),
            const SizedBox(height: AppSpacing.xs),
            _MacroRow(
              label: 'Fat',
              valueG: remainingFatG,
              color: AppColors.macroFat,
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  const _MacroRow({
    required this.label,
    required this.valueG,
    required this.color,
  });

  final String label;
  final double valueG;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.macroLabel(context)),
              Text(
                '${valueG.toStringAsFixed(0)} g',
                style: AppTextStyles.macroValue(context),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
