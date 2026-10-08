import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_icons.dart';
import '../../theme/app_typography.dart';
import '../design/design_button.dart';
import '../design/settings_row.dart';

/// 検索結果の末尾。押したときだけ推定を聞く。
class AiFoodLookupRow extends StatelessWidget {
  const AiFoodLookupRow({super.key, required this.onTap});

  static const label = 'AIで探す (β)';
  static const subtitle = '無い食品も、AIが推定します';

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

/// 検索が0件のとき。説明は足さず、一文とボタンだけを出す。
class AiFoodLookupEmptySuggestion extends StatelessWidget {
  const AiFoodLookupEmptySuggestion({super.key, required this.onTap});

  static const message = 'この食品の登録がありませんでした。AIで検索しますか？';

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('ai-food-lookup-empty'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyS.copyWith(color: AppColors.textMuted),
          ),
        ),
        DesignButton(
          label: AiFoodLookupRow.label,
          showTrailingIcon: false,
          onPressed: onTap,
        ),
      ],
    );
  }
}
