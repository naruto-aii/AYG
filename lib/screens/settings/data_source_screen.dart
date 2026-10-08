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
            subtitle: '100gあたりの数値と、表示名の付け方です。',
          ),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(OfficialFoodCopy.nutritionPer100g, style: body),
                const SizedBox(height: AppSpacing.sm),
                Text(OfficialFoodCopy.traceAndEstimate, style: body),
                const SizedBox(height: AppSpacing.sm),
                Text(OfficialFoodCopy.scaledToGrams, style: body),
                const SizedBox(height: AppSpacing.sm),
                Text(OfficialFoodCopy.nameProcessing, style: body),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  key: const ValueKey('data_source_mext_link'),
                  onPressed: () => openMextFoodCompositionPage(launch: launch),
                  child: const Text(OfficialFoodCopy.externalLinkLabel),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('写真で登録 (β) の推定', style: AppTypography.titleS),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '食事の写真と、入力した料理名と量から、AIがカロリーとPFCを推定します。成分表の数値ではありません。登録の前に確認して、直せます。写真はカロナビに保存しません。',
                  style: body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('自炊コーチ (β) の栄養', style: AppTypography.titleS),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '料理の中身はAIが決めます。食材のグラムに対するカロリーとPFCは、日本食品標準成分表の値で計算します。成分表に無い食品だけ、AIの目安を使います。画面に、この食事の目標との差を出します。',
                  style: body,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          DesignCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('パーソナルコーチ (β) の量と区分', style: AppTypography.titleS),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '主食・主菜・副菜・乳製品・果物の組み合わせと、1品の量は次の資料の数値を使っています。',
                  style: body,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '農林水産省「食事バランスガイド」\n'
                  'https://www.maff.go.jp/j/syokuiku/kenzensyokuseikatsu/about_b_guide.html',
                  style: body,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '農林水産省「SV早見表」\n'
                  'https://www.maff.go.jp/j/syokuiku/zissen_navi/balance/chart.html',
                  style: body,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '厚生労働省「生活習慣病予防その他の健康増進を目的として提供する食事について（目安）」\n'
                  'https://www.mhlw.go.jp/file/04-Houdouhappyou-10904750-Kenkoukyoku-Gantaisakukenkouzoushinka/0000096859.pdf',
                  style: body,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'スマートミール基準\nhttps://smartmeal.jp/smartmealkijun.html',
                  style: body,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '厚生労働省 健健発0804第1号 別表「緑黄色野菜」\n'
                  'https://www.mhlw.go.jp/web/t_doc?dataId=00tc6109&dataType=1&pageNo=1',
                  style: body,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  '文部科学省「日本食品標準成分表（八訂）増補2023年」\n'
                  'https://www.mext.go.jp/a_menu/syokuhinseibun/mext_00001.html',
                  style: body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
