import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/met_activity_catalog.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/layout/app_content_constraint.dart';

/// 消費カロリー推定の根拠と参考文献。
class CalculationReferencesScreen extends StatelessWidget {
  const CalculationReferencesScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('リンクを開けませんでした: $url')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);

    return Scaffold(
      appBar: AppBar(title: const Text('計算根拠・参考文献')),
      body: SafeArea(
        child: AppContentConstraint(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('推定値について', style: titleStyle),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '本アプリが表示する消費カロリーは測定値ではなく推定値です。'
                      '個人差、年齢、体組成、フォーム、休憩時間、環境などにより実際の消費量と異なる場合があります。',
                      style: bodyStyle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text('医療上の診断、治療、助言を目的とするものではありません。', style: bodyStyle),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('使用する入力', style: titleStyle),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '・MET（運動強度）\n'
                      '・実施時間（分）\n'
                      '・運動実施日時以前で最も新しい体重記録（なければプロフィール体重）',
                      style: bodyStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('計算式', style: titleStyle),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'gross（総消費）:\n'
                      'MET × 3.5 × 体重(kg) ÷ 200 × 時間(分)\n\n'
                      'net（追加消費）:\n'
                      'max(MET − 1.0, 0) × 3.5 × 体重(kg) ÷ 200 × 時間(分)',
                      style: bodyStyle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'ホーム画面の「あと x kcal」には net（安静時1 MET相当を除いた分）のみを加算します。',
                      style: bodyStyle,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '計算バージョン: ${MetActivityCatalog.calculationVersion}\n'
                      '最終更新: ${MetActivityCatalog.lastUpdated}',
                      style: bodyStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('参考文献', style: titleStyle),
                    const SizedBox(height: AppSpacing.sm),
                    _ReferenceTile(
                      title:
                          'Herrmann SD, Willis EA, Ainsworth BE, et al. (2024)',
                      subtitle:
                          '2024 Adult Compendium of Physical Activities. '
                          'Journal of Sport and Health Science.',
                      linkLabel: 'DOI: 10.1016/j.jshs.2023.10.010',
                      url: 'https://doi.org/10.1016/j.jshs.2023.10.010',
                      onOpen: (url) => _openUrl(context, url),
                    ),
                    const Divider(height: AppSpacing.lg),
                    _ReferenceTile(
                      title: 'Compendium of Physical Activities',
                      subtitle: '2024 Adult Compendium / Definition of MET',
                      linkLabel: 'https://pacompendium.com/',
                      url: 'https://pacompendium.com/',
                      onOpen: (url) => _openUrl(context, url),
                    ),
                    const Divider(height: AppSpacing.lg),
                    _ReferenceTile(
                      title: 'Compendium Calculator with Examples',
                      subtitle: 'MET計算の参考例',
                      linkLabel:
                          'https://pacompendium.com/compendium-calculator/',
                      url: 'https://pacompendium.com/compendium-calculator/',
                      onOpen: (url) => _openUrl(context, url),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  const _ReferenceTile({
    required this.title,
    required this.subtitle,
    required this.linkLabel,
    required this.url,
    required this.onOpen,
  });

  final String title;
  final String subtitle;
  final String linkLabel;
  final String url;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xxs),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        TextButton(onPressed: () => onOpen(url), child: Text(linkLabel)),
      ],
    );
  }
}
