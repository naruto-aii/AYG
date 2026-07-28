import 'package:flutter/material.dart';

import '../../theme/app_spacing.dart';
import '../../widgets/brand/app_logo.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/layout/app_content_constraint.dart';

/// 体重履歴タブ（将来: 毎日の体重入力・履歴）。
class WeightPlaceholderScreen extends StatelessWidget {
  const WeightPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AppContentConstraint(
          expandVertically: true,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogo(height: 28),
                const SizedBox(height: AppSpacing.sm),
                Text('体重', style: Theme.of(context).textTheme.headlineMedium),
                const Expanded(
                  child: AppEmptyState(
                    icon: Icons.monitor_weight_outlined,
                    message: '体重履歴は準備中です。\nホームから体重を記録できます。',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
