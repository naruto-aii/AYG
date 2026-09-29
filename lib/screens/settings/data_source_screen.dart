import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/official_food_copy.dart';
import '../../services/official_food_link.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';

/// 設定の「データの出典」。
class DataSourceScreen extends StatelessWidget {
  const DataSourceScreen({super.key, this.launch});

  final Future<bool> Function(Uri uri, LaunchMode mode)? launch;

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.bodyS.copyWith(color: AppColors.textPrimary);
    return DesignPage(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'データの出典',
            subtitle: '食品成分表の値と、アプリが足した別名についての説明です。',
          ),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(OfficialFoodCopy.sourceSentence, style: body),
                const SizedBox(height: AppSpacing.sm),
                Text(OfficialFoodCopy.aliasSentence, style: body),
                const SizedBox(height: AppSpacing.sm),
                Text(OfficialFoodCopy.disclaimerSentence, style: body),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  key: const ValueKey('data_source_mext_link'),
                  onPressed: () => openMextFoodCompositionPage(launch: launch),
                  child: const Text(OfficialFoodCopy.externalLinkLabel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
