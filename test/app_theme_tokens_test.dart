import 'package:ayg/theme/app_colors.dart';
import 'package:ayg/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Figma color tokens match the delivered palette', () {
    expect(AppColors.bgPage, const Color(0xFFFEF9EE));
    expect(AppColors.bgPrimary, const Color(0xFF2D7448));
    expect(AppColors.textPrimary, const Color(0xFF14522F));
    expect(AppColors.accentOrange, const Color(0xFFF6892B));
    expect(AppColors.primaryGreen, AppColors.bgPrimary);
    expect(AppColors.backgroundCream, AppColors.bgPage);
  });

  test('typography uses Zen Maru Gothic with Japanese fallback', () {
    expect(AppTypography.fontFamily, 'Zen Maru Gothic');
    expect(AppTypography.textTheme.headlineLarge?.fontFamily, 'Zen Maru Gothic');
    expect(
      AppTypography.textTheme.headlineLarge?.fontFamilyFallback,
      contains('Hiragino Sans'),
    );
    expect(AppTypography.textTheme.headlineLarge?.height, 1.3);
  });
}
