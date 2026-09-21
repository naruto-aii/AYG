import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';

/// Figma: StepIndicator（初回設定 n/3）。
class StepIndicator extends StatelessWidget {
  const StepIndicator({
    super.key,
    required this.current,
    this.total = 3,
    this.title = '初回設定',
  });

  /// 1 始まり。
  final int current;
  final int total;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$title  $current/$total',
          style: AppTypography.labelM.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= total; i++) ...[
              if (i > 1) const SizedBox(width: 6),
              Container(
                width: 46,
                height: 6,
                decoration: BoxDecoration(
                  color: i <= current
                      ? AppColors.bgPrimary
                      : AppColors.bgTrack,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
