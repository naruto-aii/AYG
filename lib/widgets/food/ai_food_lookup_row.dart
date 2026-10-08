import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
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
