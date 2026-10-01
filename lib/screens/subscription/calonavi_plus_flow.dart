import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_page.dart';
import '../legal/legal_document.dart';
import '../legal/legal_document_screen.dart';

/// ウィジェット作成からカロナビ+へ進む。
///
/// レシート検証と購入ボタンは、このブランチの売り方には足さない。
/// 購入画面そのものは `showCalonaviPlus` が開く先で、後から差し替えられる。
Future<void> showCalonaviPlus(BuildContext context) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (context) => const CalonaviPlusEntryScreen(),
    ),
  );
}

class CalonaviPlusEntryScreen extends StatelessWidget {
  const CalonaviPlusEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bodyPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(
            title: 'カロナビ+',
            subtitle: 'ウィジェットからの登録は、カロナビ+の機能です。',
          ),
          Text(AppStrings.siriVoicePaidGuidance, style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.md),
          Text('購入と復元は、カロナビ+の購入画面で行います。', style: AppTypography.bodyS),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () =>
                showLegalDocument(context, LegalDocument.tokushoho),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('特定商取引法に基づく表記', style: AppTypography.labelM),
          ),
        ],
      ),
    );
  }
}
