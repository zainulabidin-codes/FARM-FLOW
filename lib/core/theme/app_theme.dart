import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// DairyFarm Pro — Design Tokens
// Extracted from visual reference mockups (soft-card aesthetic, sage-green
// accents, dark-slate typography, light-grey backgrounds).
// ---------------------------------------------------------------------------

/// Primary brand colours.
abstract final class AppColors {
  /// Sage green accent — used for primary buttons, active states, badges.
  static const Color sageGreen = Color(0xFF81C995);

  /// Deep forest green — used for dark primary buttons (Save Entry, Login).
  static const Color deepGreen = Color(0xFF2D6A4F);

  /// Light grey page scaffold background.
  static const Color bgGrey = Color(0xFFF5F5F7);

  /// Pure white — card surfaces.
  static const Color cardWhite = Color(0xFFFFFFFF);

  /// Soft grey — used inside cards for sub-containers.
  static const Color cardSubtle = Color(0xFFF0F0F3);

  /// Primary text — nearly-black dark slate.
  static const Color textDark = Color(0xFF1C1C1E);

  /// Secondary / muted text.
  static const Color textGrey = Color(0xFF8E8E93);

  /// Warning / error red.
  static const Color warningRed = Color(0xFFFF6B6B);

  /// Soft sage tint for icon backgrounds and mint tags.
  static const Color sageTint = Color(0xFFE8F5E9);

  /// Warm amber — used for "Pregnant" status badges.
  static const Color pregnantAmber = Color(0xFFFFF3E0);

  /// Amber text for "Pregnant" chip labels.
  static const Color pregnantAmberText = Color(0xFFF57C00);

  /// Dry/neutral status — light slate.
  static const Color dryGrey = Color(0xFFEEEEEE);

  /// Dry/neutral text.
  static const Color dryGreyText = Color(0xFF757575);
}

// ---------------------------------------------------------------------------
// Global ThemeData
// ---------------------------------------------------------------------------
abstract final class AppTheme {
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    )
  ];

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',

      // Colour scheme anchored to sage green.
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.sageGreen,
        brightness: Brightness.light,
        surface: AppColors.bgGrey,
        onSurface: AppColors.textDark,
      ),

      scaffoldBackgroundColor: AppColors.bgGrey,

      // ── Card theme ──────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadowColor: Colors.black.withValues(alpha: 0.06),
        margin: EdgeInsets.zero,
      ),

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bgGrey,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppColors.textDark,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),

      // ── Elevated button ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.deepGreen,
          foregroundColor: AppColors.cardWhite,
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Outlined button ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.deepGreen,
          side: const BorderSide(color: AppColors.deepGreen, width: 1.5),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),

      // ── Input decoration ────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFEEF1EE),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: 16.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFFD8DED8), width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFFD8DED8), width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Color(0xFF00522A), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.0),
        ),
        hintStyle: TextStyle(
          color: Colors.grey[500],
          fontSize: 15,
        ),
        labelStyle: TextStyle(
          color: Colors.grey[500],
          fontSize: 15,
        ),
      ),

      // ── Text theme ──────────────────────────────────────────────────────
      textTheme: const TextTheme(
        // Used for the massive number displays (245.5L, 18)
        displayLarge: TextStyle(
          color: AppColors.deepGreen,
          fontSize: 56,
          fontWeight: FontWeight.w800,
          letterSpacing: -2,
          height: 1.0,
        ),
        // Section headers and card titles
        headlineMedium: TextStyle(
          color: AppColors.textDark,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineSmall: TextStyle(
          color: AppColors.textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        // Standard body copy
        bodyLarge: TextStyle(
          color: AppColors.textDark,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: TextStyle(
          color: AppColors.textGrey,
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        // Small labels (e.g. "LITRES" stamp above number)
        labelSmall: TextStyle(
          color: AppColors.textGrey,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
        ),
        // Chip / tag labels
        labelMedium: TextStyle(
          color: AppColors.textDark,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),

      // ── Bottom navigation bar ────────────────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardWhite,
        selectedItemColor: AppColors.deepGreen,
        unselectedItemColor: AppColors.textGrey,
        selectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // ── Chip theme ───────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.dryGrey,
        selectedColor: AppColors.sageGreen,
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),

      // ── Divider ──────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E5EA),
        thickness: 1,
        space: 1,
      ),
    );
  }

  /// Helper for creating clean filled input field decorations across forms
  static InputDecoration filledInputDecoration({
    required String labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    Widget? prefix,
    String? errorText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      prefix: prefix,
      errorText: errorText,
      filled: true,
      fillColor: const Color(0xFFEEF1EE),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 16.0),
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(color: Color(0xFFD8DED8), width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(color: Color(0xFFD8DED8), width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(color: AppColors.deepGreen, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(color: AppColors.warningRed, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14.0),
        borderSide: const BorderSide(color: AppColors.warningRed, width: 1.5),
      ),
    );
  }
}

