import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

/// カロナビ Material 3 テーマ。
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryGreen,
      onPrimary: Colors.white,
      primaryContainer: AppColors.softGreen,
      onPrimaryContainer: AppColors.primaryText,
      secondary: AppColors.accentOrange,
      onSecondary: AppColors.primaryText,
      secondaryContainer: Color(0xFFFFE8CC),
      onSecondaryContainer: AppColors.primaryText,
      surface: AppColors.backgroundCream,
      onSurface: AppColors.primaryText,
      onSurfaceVariant: AppColors.secondaryText,
      outline: AppColors.border,
      error: AppColors.error,
      onError: Colors.white,
      tertiary: AppColors.macroFat,
      onTertiary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.backgroundCream,
      textTheme: AppTypography.textTheme,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: AppColors.backgroundCream,
        foregroundColor: AppColors.primaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardWhite,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
          side: const BorderSide(color: AppColors.borderGreen, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.borderGreen),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryGreen,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardWhite,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(
            color: AppColors.primaryGreen,
            width: 1.5,
          ),
        ),
        labelStyle: const TextStyle(color: AppColors.secondaryText),
        hintStyle: const TextStyle(color: AppColors.secondaryText),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardWhite,
        indicatorColor: AppColors.softGreen.withValues(alpha: 0.5),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? AppColors.primaryGreen : AppColors.secondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primaryGreen : AppColors.secondaryText,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        backgroundColor: AppColors.primaryText,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.cardWhite,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.bottomNav),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.backgroundCream,
        selectedColor: AppColors.softGreen,
        labelStyle: const TextStyle(color: AppColors.primaryText),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.chip,
          side: const BorderSide(color: AppColors.borderGreen),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.accentOrange,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
    );
  }
}
