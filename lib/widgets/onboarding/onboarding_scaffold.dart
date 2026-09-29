import 'package:flutter/material.dart';

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
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: AppLogo(height: 28),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle!, style: Theme.of(context).textTheme.bodyLarge),
            ],
            const SizedBox(height: AppSpacing.lg),
            AppCard(large: true, child: body),
            const SizedBox(height: AppSpacing.lg),
            action,
          ],
        ),
      ),
    );
  }
}
