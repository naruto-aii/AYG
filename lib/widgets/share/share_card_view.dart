import 'package:flutter/material.dart';

import '../../constants/app_strings.dart';
import '../../services/share_card_content.dart';
import '../../services/share_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_typography.dart';
import '../brand/app_brand_mark.dart';

/// 今日のまとめの共有カード。正方形、白と緑、アプリアイコン、入手先。
class ShareCardView extends StatelessWidget {
  const ShareCardView({super.key, required this.content});

  final ShareCardContent content;

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: ColoredBox(
        color: AppColors.bgPage,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned(
                right: -46,
                top: -36,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: const BoxDecoration(
                    color: AppColors.green100,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _BrandLockup(),
                    const SizedBox(height: 6),
                    Text(
                      content.dateLabel,
                      style: _text(AppTypography.caption),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      content.eyebrow,
                      style: _text(
                        AppTypography.titleM,
                        color: AppColors.textBrand,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _headline(),
                    const SizedBox(height: 6),
                    Text(
                      content.detail,
                      style: _text(
                        AppTypography.bodyM,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (content.macros != null) ...[
                      const SizedBox(height: 8),
                      _MacroBar(balance: content.macros!),
                    ],
                    const Spacer(),
                    Text(
                      AppStrings.loginTagline,
                      style: _text(
                        AppTypography.bodyM,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _DownloadFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headline() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            content.headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _text(AppTypography.displayNumber, fontSize: 42),
          ),
        ),
        if (content.unit.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(
            content.unit,
            style: _text(
              AppTypography.headingS,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

class _MacroBar extends StatelessWidget {
  const _MacroBar({required this.balance});

  final ShareMacroBalance balance;

  @override
  Widget build(BuildContext context) {
    final slices = [
      (balance.protein, AppColors.macroProtein, 'たんぱく質'),
      (balance.fat, AppColors.macroFat, '脂質'),
      (balance.carb, AppColors.macroCarb, '炭水化物'),
    ].where((slice) => slice.$1 > 0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.full),
          child: SizedBox(
            height: 14,
            child: Row(
              children: [
                for (final slice in slices)
                  Expanded(
                    flex: slice.$1,
                    child: ColoredBox(color: slice.$2),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final slice in [
              (balance.protein, 'たんぱく質'),
              (balance.fat, '脂質'),
              (balance.carb, '炭水化物'),
            ])
              Expanded(
                child: Text(
                  '${slice.$2}\n${slice.$1}%',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption.copyWith(
                    fontFamily: AppTypography.fontFamily,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ],
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
