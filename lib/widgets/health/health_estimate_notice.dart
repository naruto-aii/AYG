import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// カロリーや食事の提案が、診断や治療ではないこと。
///
/// 数値を出す画面に置く。計算根拠の奥だけだと、提案を見た人が免責に届かない。
class HealthEstimateNotice extends StatelessWidget {
  const HealthEstimateNotice({super.key, this.textAlign = TextAlign.start});

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppStrings.healthEstimateDisclaimer,
      key: const Key('health-estimate-disclaimer'),
      textAlign: textAlign,
      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
    );
  }
}
