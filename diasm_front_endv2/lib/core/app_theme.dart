import 'package:flutter/material.dart';

/// Central colour palette for DIAsm
class AppColors {
  // Brand teal palette (Health2Sync-like)
  static const Color primaryDark = Color(0xFF1D8B83); // darker teal
  static const Color primary = Color(0xFF27B4A8);     // main brand teal
  static const Color accent = Color(0xFF3ED0BC);      // lighter teal / accent
  static const Color success = Color(0xFF10B981);     // green for good status

  // Soft background (almost white, not yellow)
  static const Color background = Color(0xFFF7FAF9);

  // Surfaces & text
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF172B3A);   // deep navy
  static const Color textSecondary = Color(0xFF6B7280); // grey
  static const Color borderSoft = Color(0xFFE1ECE9);
  static const Color error = Color(0xFFDC2626);

  // Optional hero gradient for top area (if we use it on Home)
  static const Color heroTop = primary;
  static const Color heroBottom = Color(0xFF3ED0BC);
}

/// Text styles used throughout the app.
class AppTextStyles {
  static const TextStyle appBarTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle heading = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    color: Colors.white,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodySecondary = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    color: AppColors.textSecondary,
  );

  static const TextTheme textTheme = TextTheme(
    headlineLarge: heading,
    headlineMedium: heading,
    titleLarge: title,
    titleMedium: title,
    bodyLarge: body,
    bodyMedium: bodySecondary,
    labelLarge: button,
  );
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    const primary = AppColors.primary;
    const background = AppColors.background;

    final base = ThemeData(
      useMaterial3: true,

      // Global font
      fontFamily: 'Inter',
      textTheme: AppTextStyles.textTheme.apply(fontFamily: 'Inter'),

      primaryColor: primary,
      scaffoldBackgroundColor: background,

      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        error: AppColors.error,
        onError: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),

      // AppBar – teal with white content
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: AppTextStyles.appBarTitle.copyWith(
          fontFamily: 'Inter',
          color: Colors.white,
        ),
      ),

      // Cards – white, rounded, soft elevation
     // Cards – white, rounded, soft elevation
cardTheme: CardThemeData(
  color: AppColors.surface,
  elevation: 2,
  shadowColor: Colors.black.withOpacity(0.05),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(20),
  ),
  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
),


      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderSoft),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        labelStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),

      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),

      // Chips
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        selectedColor: AppColors.success.withOpacity(0.18),
        backgroundColor: AppColors.surface,
        labelStyle: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),

      // Switches
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.all(Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.borderSoft;
        }),
      ),

      // Bottom navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedIconTheme: IconThemeData(color: AppColors.primary),
        selectedLabelStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        showUnselectedLabels: true,
      ),
    );

    return base;
  }
}
