import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../services/share_card_content.dart';
import '../../services/share_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../brand/app_brand_mark.dart';
import '../design/calorie_ring.dart';

/// 今日の摂取カロリーの共有カード。主役はホームと同じ若葉の丸。
class ShareCardView extends StatelessWidget {
  const ShareCardView({super.key, required this.content});

  final ShareCardContent content;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ColoredBox(
        color: AppColors.bgPage,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: _BrandLockup(),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  content.dateLabel,
                  style: _text(AppTypography.caption),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  content.eyebrow,
                  style: _text(
                    AppTypography.titleM,
                    color: AppColors.textBrand,
                  ),
                ),
              ),
              const Spacer(),
              CalorieRing(
                label: '',
                value: content.figure,
                progress: content.progress,
                progressColor: content.isOverage ? AppColors.orange500 : null,
                size: 164,
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  AppStrings.loginTagline,
                  maxLines: 1,
                  softWrap: false,
                  style: _text(
                    AppTypography.bodyM,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const _DownloadFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AppBrandMark(size: 28),
        const SizedBox(width: 8),
        Text(
          AppStrings.appTitle,
          style: AppTypography.headingS.copyWith(
            fontFamily: AppTypography.fontFamily,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DownloadFooter extends StatelessWidget {
  const _DownloadFooter();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'iPhoneでカロナビ',
            style: AppTypography.titleM.copyWith(
              fontFamily: AppTypography.fontFamily,
              color: AppColors.textOnPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            shareDownloadLabel,
            style: AppTypography.caption.copyWith(
              fontFamily: AppTypography.fontFamily,
              color: AppColors.green100,
            ),
          ),
        ],
      ),
    );
  }
}

TextStyle _text(TextStyle style, {Color? color, double? fontSize}) {
  return style.copyWith(
    fontFamily: AppTypography.fontFamily,
    color: color,
    fontSize: fontSize,
  );
}
