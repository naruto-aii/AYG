import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';

/// 自分でショートカットは作らない。Siri とログインだけ先に済ます。
const String siriSetupLead =
    'ショートカットを自分で作る必要はありません。Siriをオンにして、カロナビにログインした状態で話しかけます。';

const String siriSetupSteps =
    'Siriをオンにする\n'
    '設定アプリ →「Siriと検索」（「Apple IntelligenceとSiri」のときもある）→「"Hey Siri"を聞き取る」をオン。はじめてオンにするときは、画面の案内どおりに声を登録する。サイドボタンで話すときは「サイドボタンを押してSiriを使用」をオン。\n'
    '\n'
    'ログインする\n'
    'カロナビを開いて、ログインした状態にしておく。ログインしていないと、Siriは登録せず「ログインしてください」と返す。\n'
    '\n'
    '話しかける\n'
    '「Hey Siri、カロナビで」のあとに、下の例のとおり食事か運動と量を話す。復唱を聞いて、合っていれば「はい」。\n'
    '\n'
    'ショートカットの追加は不要\n'
    '「食事を登録」「運動を登録」「食事か運動を登録」は、アプリを入れた時点で使える。言い方を変えるときだけ、ショートカットアプリで編集する。';

/// カロナビ+が有効なときの音声登録。購入画面は出さない。
class SiriVoiceSetupScreen extends StatelessWidget {
  const SiriVoiceSetupScreen({super.key});

  Future<void> _openShortcuts(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('shortcuts://'),
      mode: LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ショートカットを開けませんでした。ホーム画面からショートカットアプリを開いてください。'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DesignPage(
      bottomBar: DesignButton(
        key: const Key('siri-open-shortcuts'),
        label: 'ショートカットを開く',
        showTrailingIcon: false,
        onPressed: () => _openShortcuts(context),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignTitleBlock(title: '音声登録', subtitle: siriSetupLead),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('使い始める前', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  siriSetupSteps,
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('話し方', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppStrings.siriVoicePaidGuidance,
                  style: AppTypography.bodyS,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  '「Hey Siri、カロナビで」のあとに、食事か運動と量を話します。復唱を聞いて、合っていれば「はい」で登録されます。',
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('言い方を変えるとき', style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '最初から入っています。言い方を変えるときだけ、ショートカットアプリのカロナビにある「食事を登録」「運動を登録」「食事か運動を登録」を編集します。',
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
