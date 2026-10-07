import 'package:flutter/material.dart';

import '../../services/analytics/analytics_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// 初回起動（ログインより前）の同意。初期選択は無い。社長確認用の文案。
class AnalyticsConsentScreen extends StatelessWidget {
  const AnalyticsConsentScreen({
    super.key,
    required this.onDecide,
  });

  final Future<void> Function(bool cooperate) onDecide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('利用状況の記録', style: AppTypography.titleM),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    'カロナビは、使いにくい画面を直すためと、どの機能がカロナビ+の利用につながっているかを見るために、操作の記録を残したいと考えています。\n\n'
                    '残すのは、画面の表示、ボタンやウィジェットや Siri の操作、検索の結果件数、エラー、アプリと端末の版、端末の機種、このインストールだけのランダムな番号です。体重、カロリー、メモの本文は残しません。\n\n'
                    '広告の配信には使いません。協力しなくても、記録もカロナビ+も、すべての機能を使えます。あとから設定の「利用状況の記録」でやめられます。',
                    style: AppTypography.bodyM,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 52,
                child: FilledButton(
                  key: const Key('analytics-consent-yes'),
                  onPressed: () => onDecide(true),
                  child: const Text('利用状況の記録に協力する'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 52,
                child: OutlinedButton(
                  key: const Key('analytics-consent-no'),
                  onPressed: () => onDecide(false),
                  child: const Text('協力しない'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '文案の版 ${analyticsPolicyVersion}（社長確認前）',
                style: AppTypography.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
