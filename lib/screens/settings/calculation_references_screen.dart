import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/met_activity_catalog.dart';
import '../../models/calculation/calculation_versions.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/layout/app_content_constraint.dart';

/// 計算根拠・参考文献（文献引用とプロダクト既定値を区別）。
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
                      '表示されるカロリー・栄養素・運動消費量は一般的な式に基づく推定値です。'
                      '医療上の診断や治療を目的としたものではありません。',
                      style: bodyStyle,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              _CategorySection(
                title: '摂取目標カロリー',
                version: CalculationVersions.energy,
                summary:
                    '推定安静時消費（Mifflin–St Jeor 式）× 普段の生活活動係数 ± 目標補正（アプリ既定）。'
                    '別途記録した運動は食事目標に含めません。',
                references: const [
                  _Ref(
                    authors: 'Mifflin MD, St Jeor ST, et al.',
                    title:
                        'A new predictive equation for resting energy expenditure in healthy individuals.',
                    journal: 'American Journal of Clinical Nutrition. 1990.',
                    url: 'https://pubmed.ncbi.nlm.nih.gov/2305711/',
                    usage: '成人の推定安静時消費カロリー（REE）の算出に使用。',
                  ),
                  _Ref(
                    authors: 'Frankenfield D, et al.',
                    title:
                        'Comparison of predictive equations for resting metabolic rate in healthy nonobese and obese adults.',
                    journal:
                        'Journal of the American Dietetic Association. 2005.',
                    url: 'https://pubmed.ncbi.nlm.nih.gov/15883556/',
                    usage: 'REE 推定式の比較文献として参考。',
                  ),
                ],
                onOpen: (url) => _openUrl(context, url),
              ),
              const SizedBox(height: AppSpacing.md),
              _CategorySection(
                title: 'PFC目標',
                version: CalculationVersions.macro,
                summary:
                    'たんぱく質は g/kg で決定、脂質は AMDR 内のエネルギー比率（アプリ既定）、'
                    '炭水化物は残余配分。AMDR は参考範囲であり唯一の最適比率ではありません。',
                references: const [
                  _Ref(
                    authors:
                        'National Academies of Sciences, Engineering, and Medicine.',
                    title:
                        'Dietary Reference Intakes / Acceptable Macronutrient Distribution Ranges.',
                    journal: 'NCBI Bookshelf.',
                    url: 'https://www.ncbi.nlm.nih.gov/books/NBK610333/',
                    usage: 'P/F/C の AMDR 参考範囲（10–35% / 20–35% / 45–65%）。',
                  ),
                  _Ref(
                    authors: 'Jäger R, et al.',
                    title:
                        'International Society of Sports Nutrition Position Stand: protein and exercise.',
                    journal:
                        'Journal of the International Society of Sports Nutrition. 2017.',
                    url: 'https://pubmed.ncbi.nlm.nih.gov/28642676/',
                    usage: '運動する成人のたんぱく質 g/kg の参考範囲（1.4–2.0）。',
                  ),
                  _Ref(
                    authors: 'Aragon AA, et al.',
                    title:
                        'International Society of Sports Nutrition position stand: diets and body composition.',
                    journal:
                        'Journal of the International Society of Sports Nutrition. 2017.',
                    url: 'https://pubmed.ncbi.nlm.nih.gov/28630601/',
                    usage: '体組成と栄養の位置づけの参考。',
                  ),
                ],
                onOpen: (url) => _openUrl(context, url),
              ),
              const SizedBox(height: AppSpacing.md),
              _CategorySection(
                title: '運動消費カロリー',
                version: MetActivityCatalog.calculationVersion,
                summary:
                    '日常語で選んだ種目・強度から内部 MET を決定。'
                    'gross = 運動中の総消費、net = 安静時1 MET相当を除いた追加分。'
                    'ホームの残りカロリーには net のみ加算。',
                references: [
                  ...MetActivityCatalog.ledger.map(
                    (entry) => _Ref(
                      authors: entry.citation.split('.').first,
                      title: entry.citation,
                      journal: entry.rightsCategory,
                      url: entry.sourceKey.contains('doi')
                          ? 'https://doi.org/${MetActivityCatalog.herrmann2024Doi}'
                          : 'https://pacompendium.com/',
                      usage: 'MET 値の出典台帳（${entry.sourceKey}）。',
                    ),
                  ),
                ],
                onOpen: (url) => _openUrl(context, url),
              ),
              const SizedBox(height: AppSpacing.md),
              _CategorySection(
                title: '体重変化についての注意',
                version: CalculationVersions.energy,
                summary:
                    '体重変化の速度は一定ではありません。身体の適応により、'
                    '同じカロリー差でも経時的に変化率が変わることがあります。'
                    '本アプリは 7,200 kcal/kg などの単純補正を「アプリの初期設定」として用い、'
                    '長期予測には使用しません。',
                references: const [
                  _Ref(
                    authors:
                        'National Institute of Diabetes and Digestive and Kidney Diseases.',
                    title: 'Body Weight Planner / Dynamic model research.',
                    journal: 'NIDDK.',
                    url:
                        'https://www.niddk.nih.gov/research-funding/at-niddk/labs-branches/laboratory-biological-modeling/integrative-physiology-section/research/body-weight-planner',
                    usage: '体重変化が動的であるという原則の参考（数式・表の転載はしていません）。',
                  ),
                ],
                onOpen: (url) => _openUrl(context, url),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.version,
    required this.summary,
    required this.references,
    required this.onOpen,
  });

  final String title;
  final String version;
  final String summary;
  final List<_Ref> references;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: AppSpacing.xs),
          Text('計算バージョン: $version', style: bodyStyle),
          const SizedBox(height: AppSpacing.sm),
          Text(summary, style: bodyStyle),
          const SizedBox(height: AppSpacing.md),
          Text('参考文献', style: titleStyle),
          ...references.map(
            (ref) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ref.authors,
                    style: bodyStyle?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(ref.title, style: bodyStyle),
                  Text(ref.journal, style: bodyStyle),
                  Text('用途: ${ref.usage}', style: bodyStyle),
                  TextButton(
                    onPressed: () => onOpen(ref.url),
                    child: Text(ref.url),
                  ),
                  const Divider(height: AppSpacing.lg),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ref {
  const _Ref({
    required this.authors,
    required this.title,
    required this.journal,
    required this.url,
    required this.usage,
  });

  final String authors;
  final String title;
  final String journal;
  final String url;
  final String usage;
}
