import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/analytics/catalog_actions.dart';
import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_page.dart';

/// 運営への問い合わせ。サポートページにあった窓口をここにまとめる。
class OperatorContactScreen extends StatelessWidget {
  const OperatorContactScreen({super.key, required this.email});

  final String email;

  Future<void> _sendMail(BuildContext context) async {
    CatalogActions.contactTap('email');
    final uri = Uri(scheme: 'mailto', path: email);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('メールを開けませんでした: $email')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = AppTypography.bodyS.copyWith(color: AppColors.textMuted);
    return DesignPage(
      bottomBar: DesignButton(
        label: 'メールを送る',
        showTrailingIcon: false,
        onPressed: () => _sendMail(context),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(title: AppStrings.settingsContactOperator),
          Text(
            '不具合、ログイン、記録、課金、アカウント削除、個人データの開示請求の窓口です。',
            style: AppTypography.bodyL.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('問い合わせ先', style: AppTypography.titleS),
          const SizedBox(height: AppSpacing.xs),
          Text(email, style: AppTypography.bodyL),
          const SizedBox(height: AppSpacing.md),
          Text('受付は順次対応です。数日以内を目安にしてください。', style: body),
          const SizedBox(height: AppSpacing.sm),
          Text('アカウントに関する依頼は、ログインに使っているメールアドレスから送ってください。', style: body),
        ],
      ),
    );
  }
}
