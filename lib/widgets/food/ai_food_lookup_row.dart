import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../design/design_button.dart';
import '../design/settings_row.dart';

/// 検索結果の末尾。押したときだけ推定を聞く。
class AiFoodLookupRow extends StatelessWidget {
  const AiFoodLookupRow({super.key, required this.onTap});

  static const label = 'AIで探す (β)';
  static const subtitle = 'データベースに無い食品も、AIが推定します。登録の前に数値を直せます。';

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SettingsRow(
      key: const Key('ai-food-lookup-row'),
      icon: AppIcons.search,
      title: label,
      subtitle: subtitle,
      onTap: onTap,
    );
  }
}

/// 検索が0件のとき。同じ確認画面へ進むボタンを、結果の代わりに出す。
class AiFoodLookupEmptySuggestion extends StatelessWidget {
  const AiFoodLookupEmptySuggestion({super.key, required this.onTap});

  static const headline = 'データベースには見当たりません';
  static const body = 'AIで探す (β) なら、この食品名からカロリーとPFCを推定できます。登録の前に確認して、数値を直せます。';

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('ai-food-lookup-empty'),
      decoration: BoxDecoration(
        color: AppColors.green50,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.green200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(headline, style: AppTypography.titleS),
            const SizedBox(height: 6),
            Text(
              body,
              style: AppTypography.bodyS.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            DesignButton(
              label: AiFoodLookupRow.label,
              showTrailingIcon: false,
              height: 48,
              onPressed: onTap,
            ),
          ],
        ),
      ),
    );
  }
}
