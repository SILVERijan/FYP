import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Ultra-minimal high-contrast colors (Uber style)
  static const Color primaryBlack = Color(0xFF000000);
  static const Color primaryWhite = Color(0xFFFFFFFF);
  static const Color accentCrimson = Color(0xFFE31C23); // Bold Red
  static const Color neutralGrey = Color(0xFFF1F1F1);
  static const Color darkGrey = Color(0xFF2E2E2E);
  static const Color citymapperGreen = Color(0xFF2ecc71); // For success/status

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentCrimson,
        primary: primaryBlack,
        secondary: accentCrimson,
        surface: primaryWhite,
        onSurface: primaryBlack,
      ),
      scaffoldBackgroundColor: primaryWhite,
      textTheme: GoogleFonts.lexendTextTheme().copyWith(
        displayLarge: GoogleFonts.lexend(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: primaryBlack,
          letterSpacing: -1.0,
        ),
        headlineMedium: GoogleFonts.lexend(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: primaryBlack,
          letterSpacing: -0.5,
        ),
        bodyLarge: GoogleFonts.lexend(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: primaryBlack,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryWhite,
        foregroundColor: primaryBlack,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: primaryBlack,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlack,
          foregroundColor: primaryWhite,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.lexend(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: neutralGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryBlack, width: 2),
        ),
        labelStyle: GoogleFonts.lexend(color: Colors.black54),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      ),
      cardTheme: CardThemeData(
        color: primaryWhite,
        elevation: 4,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Helper for consistent spacing
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // Glassmorphism effect simulation for markers/overlays
  static BoxDecoration get glassDecoration {
    return BoxDecoration(
      color: primaryWhite.withOpacity(0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.2)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
