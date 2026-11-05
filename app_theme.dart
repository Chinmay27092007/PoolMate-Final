import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Exact color tokens from §9.1 and pitch deck
  static const Color navyDark = Color(0xFF12263A);       // Splash/hero, app bar, dark surfaces
  static const Color navyCard = Color(0xFF1C3550);       // Cards on dark
  static const Color cream = Color(0xFFF6F4EE);          // Light page background, text on dark
  static const Color orange = Color(0xFFF4A261);         // CTAs, highlights, route line, active states
  static const Color teal = Color(0xFF1F7A6F);           // Section labels, success, secondary accent
  static const Color mutedBlueGrey = Color(0xFFA9B8C6);  // Secondary text on dark
  static const Color slate = Color(0xFF4A5B6C);          // Secondary text on light
  static const Color white = Color(0xFFFFFFFF);          // Light cards
  static const Color cardBorder = Color(0xFFE2DDD2);
  static const Color errorRed = Color(0xFFE76F51);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      primaryColor: AppColors.orange,
      colorScheme: ColorScheme.light(
        primary: AppColors.orange,
        secondary: AppColors.teal,
        surface: AppColors.cream,
        onSurface: AppColors.navyDark,
        background: AppColors.cream,
      ),
      fontFamily: 'Helvetica',
      textTheme: TextTheme(
        displayLarge: GoogleFonts.merriweather(
          color: AppColors.navyDark,
          fontSize: 36,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        displayMedium: GoogleFonts.merriweather(
          color: AppColors.navyDark,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
        titleLarge: GoogleFonts.merriweather(
          color: AppColors.navyDark,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: const TextStyle(
          color: AppColors.slate,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: const TextStyle(
          color: AppColors.slate,
          fontSize: 14,
          height: 1.4,
        ),
        labelSmall: const TextStyle(
          color: AppColors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.navyDark,
        foregroundColor: AppColors.cream,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.navyDark,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.teal,
          side: const BorderSide(color: AppColors.teal, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cream,
        side: const BorderSide(color: AppColors.cardBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.navyDark),
      ),
      cardTheme: CardTheme(
        color: AppColors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
    );
  }
}
