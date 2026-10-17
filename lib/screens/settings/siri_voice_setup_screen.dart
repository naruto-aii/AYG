import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../../widgets/design/design_button.dart';
import '../../widgets/design/design_card.dart';
import '../../widgets/design/design_page.dart';

/// 例を先に出す。手順はそのあとで短くする。
const String siriSetupExample = 'Hey Siri、カロナビに登録 → 食事 → ささみ100g';

const String siriSetupLead = siriSetupExample;

const String siriSetupSteps =
    '1. 設定アプリの「Siriと検索」で、Siriをオンにする\n'
    '2. カロナビにログインする\n'
    '3. 「Hey Siri、カロナビに登録」と話し、食事か運動を答えてから中身を話す\n'
    '違ったら「さっきの登録を取り消して」で直前の1件を消せます。';

/// 既存のテストと案内が参照する、「カロナビに登録」の流れ。
const String siriSetupRegisterExample =
    'Hey Siri、カロナビに登録 → 食事 → ささみ100g';

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
          const DesignTitleBlock(title: '音声登録 (β)'),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(siriSetupExample, style: AppTypography.titleM),
                const SizedBox(height: AppSpacing.md),
                Text(
                  siriSetupSteps,
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
