import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colour palette — shared by both dark and light themes.
abstract class AppColors {
  // Brand
  static const primary = Color(0xFF7C9EF5);
  static const primaryVariant = Color(0xFF5B7DEA);
  static const secondary = Color(0xFF4EC9B0);
  static const error = Color(0xFFF44747);
  static const warning = Color(0xFFFFCC00);
  static const info = Color(0xFF9CDCFE);

  // Dark theme surfaces
  static const darkBackground = Color(0xFF1E1E1E);
  static const darkSurface = Color(0xFF252526);
  static const darkSurfaceVariant = Color(0xFF2D2D30);
  static const darkBorder = Color(0xFF3E3E42);

  // Light theme surfaces
  static const lightBackground = Color(0xFFF5F5F5);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFEEEEEE);
  static const lightBorder = Color(0xFFDDDDDD);

  // Editor / terminal text
  static const editorForeground = Color(0xFFD4D4D4);
  static const terminalGreen = Color(0xFF4EC9B0);
  static const terminalRed = Color(0xFFF44747);
  static const terminalYellow = Color(0xFFFFCC00);

  // Agent status colours
  static const agentActive = Color(0xFF7C9EF5);
  static const agentComplete = Color(0xFF4EC9B0);
  static const agentError = Color(0xFFF44747);
  static const agentWaiting = Color(0xFFFFCC00);
}

TextTheme _monoTextTheme(TextTheme base, double fontSize) {
  return base.copyWith(
    bodyMedium: GoogleFonts.jetBrainsMono(fontSize: fontSize),
    bodySmall: GoogleFonts.jetBrainsMono(fontSize: fontSize - 1),
    labelMedium: GoogleFonts.jetBrainsMono(fontSize: fontSize - 1),
  );
}

abstract class AppTheme {
  static ThemeData dark({double editorFontSize = 14.0}) {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.darkSurface,
        onSurface: AppColors.editorForeground,
      ),
      scaffoldBackgroundColor: AppColors.darkBackground,
      cardColor: AppColors.darkSurfaceVariant,
      dividerColor: AppColors.darkBorder,
      textTheme: _monoTextTheme(base.textTheme, editorFontSize),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.editorForeground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 11, color: AppColors.editorForeground),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: AppColors.primary.withValues(alpha: 0.3),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          color: AppColors.editorForeground,
        ),
        side: const BorderSide(color: AppColors.darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  static ThemeData light({double editorFontSize = 14.0}) {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryVariant,
        secondary: AppColors.secondary,
        error: AppColors.error,
        surface: AppColors.lightSurface,
      ),
      scaffoldBackgroundColor: AppColors.lightBackground,
      cardColor: AppColors.lightSurfaceVariant,
      dividerColor: AppColors.lightBorder,
      textTheme: _monoTextTheme(base.textTheme, editorFontSize),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightSurface,
        foregroundColor: Color(0xFF1E1E1E),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.lightSurface,
        indicatorColor: AppColors.primaryVariant.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 11, color: const Color(0xFF1E1E1E)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(
            color: AppColors.primaryVariant,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}
