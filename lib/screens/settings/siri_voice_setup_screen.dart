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
    '「Hey Siri、カロナビに登録」と話す。Siriが「食事ですか、運動ですか？」と聞くので食事か運動を答え、次に「何を食べましたか？」または「何をしましたか？」と聞くので「ささみ100g」のように答える。登録すると「ささみ100gを登録しました」と読み上げます。違ったら「さっきの登録を取り消して」で消せます。「カロナビで登録」「カロナビで記録」でも同じ。\n'
    '\n'
    'ショートカットの追加は不要\n'
    '「食事を登録」「運動を登録」「食事か運動を登録」は、アプリを入れた時点で使える。言い方を変えるときだけ、ショートカットアプリで編集する。';

/// 既存の食事・運動の言い方と並べる。「カロナビに登録」の流れ。
const String siriSetupRegisterExample =
    '登録：Hey Siri、カロナビに登録。「食事ですか、運動ですか？」と聞かれたら食事か運動を答え、「何を食べましたか？」または「何をしましたか？」と聞かれたら「ささみ100g」のように答える。登録した内容を読み上げます。違ったら「さっきの登録を取り消して」で直前の1件を消せます。「カロナビで登録」「カロナビで記録」でも同じ。';

/// 「○○を100g登録」は他アプリに流れることがある。
const String siriSetupFreeformCaution =
    '「○○を100g登録」のような言い方は、リマインダーに流れることがあるので非推奨。';

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
                  siriSetupRegisterExample,
                  style: AppTypography.bodyS,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  siriSetupFreeformCaution,
                  style: AppTypography.bodyS.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'テンプレート名だけでも登録できます。登録すると内容を読み上げます。違ったら「さっきの登録を取り消して」で直前の1件を消せます。牛ももの焼き200gのように詳しく言えば、その場で登録できます。牛肉のように大まかだと、部位を聞くことがあります。曖昧なときだけ、登録の前に確認します。食品成分表と、ブロックしていない人の公開食品も登録できます。成分表は100gあたりなので、量が無いときは何gかを聞き返します。よく食べるものはテンプレートにしておくと、より確実です。',
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
