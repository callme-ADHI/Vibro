// VIBRO Theme Configuration
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  /// Main VIBRO Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      
      // Color Scheme
      colorScheme: ColorScheme.dark(
        primary: AppColors.steelBlue,
        secondary: AppColors.silverGray,
        surface: AppColors.cardBackground,
        error: AppColors.error,
        onPrimary: AppColors.platinumWhite,
        onSecondary: AppColors.platinumWhite,
        onSurface: AppColors.primaryText,
        onError: AppColors.platinumWhite,
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        iconTheme: IconThemeData(color: AppColors.platinumWhite),
        titleTextStyle: AppTypography.pageTitle(color: AppColors.primaryText),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.steelBlue,
          foregroundColor: AppColors.platinumWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.button(),
          minimumSize: const Size(0, 48),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.silverGray,
          side: BorderSide(color: AppColors.silverGray, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: AppTypography.button(),
          minimumSize: const Size(0, 48),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.steelBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: AppTypography.button(),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.silverGray.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.silverGray.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.steelBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error),
        ),
        labelStyle: AppTypography.bodyMedium(color: AppColors.secondaryText),
        hintStyle: AppTypography.bodyMedium(color: AppColors.secondaryText.withOpacity(0.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.platinumWhite;
          }
          return AppColors.silverGray;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.steelBlue;
          }
          return AppColors.silverGray.withOpacity(0.3);
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.steelBlue,
        inactiveTrackColor: AppColors.silverGray.withOpacity(0.3),
        thumbColor: AppColors.platinumWhite,
        overlayColor: AppColors.steelBlue.withOpacity(0.2),
        valueIndicatorColor: AppColors.steelBlue,
        valueIndicatorTextStyle: AppTypography.bodySmall(color: AppColors.platinumWhite),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBackground,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: AppTypography.sectionTitle(color: AppColors.primaryText),
        contentTextStyle: AppTypography.bodyMedium(color: AppColors.secondaryText),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkMidnight,
        selectedItemColor: AppColors.steelBlue,
        unselectedItemColor: AppColors.silverGray,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: AppTypography.metadata(color: AppColors.steelBlue),
        unselectedLabelStyle: AppTypography.metadata(color: AppColors.silverGray),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: AppTypography.pageTitle(color: AppColors.primaryText),
        displayMedium: AppTypography.sectionTitle(color: AppColors.primaryText),
        displaySmall: AppTypography.cardTitle(color: AppColors.primaryText),
        bodyLarge: AppTypography.bodyLarge(color: AppColors.primaryText),
        bodyMedium: AppTypography.bodyMedium(color: AppColors.primaryText),
        bodySmall: AppTypography.bodySmall(color: AppColors.secondaryText),
        labelLarge: AppTypography.button(color: AppColors.platinumWhite),
        labelMedium: AppTypography.metadata(color: AppColors.secondaryText),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: AppColors.silverGray.withOpacity(0.2),
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: AppColors.platinumWhite,
        size: 24,
      ),
    );
  }
}

/// Custom Shadows for VIBRO
class AppShadows {
  AppShadows._();

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}
