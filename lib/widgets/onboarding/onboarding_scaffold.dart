import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../brand/app_logo.dart';
import '../common/app_card.dart';

/// オンボーディング共通レイアウト。
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.action,
    this.subtitle,
    this.stepLabel,
    this.stepIndex,
    this.stepCount = 3,
    this.showLogo = true,
    this.wrapBodyInCard = true,
    this.secondaryAction,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget action;
  final String? stepLabel;
  final int? stepIndex;
  final int stepCount;
  final bool showLogo;
  final bool wrapBodyInCard;
  final Widget? secondaryAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                children: [
                  if (showLogo)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: AppLogo(height: 28),
                    ),
                  if (stepLabel != null || stepIndex != null) ...[
                    if (showLogo) const SizedBox(height: AppSpacing.md),
                    if (stepLabel != null)
                      Text(
                        stepLabel!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    if (stepIndex != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      _StepDots(index: stepIndex!, count: stepCount),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                  ] else if (showLogo)
                    const SizedBox(height: AppSpacing.lg),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      subtitle!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  if (wrapBodyInCard) AppCard(large: true, child: body) else body,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                0,
                AppSpacing.screenPadding,
                AppSpacing.md,
              ),
              child: secondaryAction == null
                  ? action
                  : Row(
                      children: [
                        Expanded(child: secondaryAction!),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(flex: 2, child: action),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i <= index ? AppColors.bgPrimary : AppColors.bgTrack,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
