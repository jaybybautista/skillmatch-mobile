import 'package:flutter/material.dart';

/// Colors and shared styling pulled from the SkillMatch UI prototypes.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF0C53A5);
  static const primaryDark = Color(0xFF00317E);
  static const primaryLight = Color(0xFF2E62B8);
  static const primaryMidBlue = Color(0xFF00649A);
  static const blueLeft = Color(0xFF00649A);
  static const background = Color(0xFFF5F7FB);
  static const surface = Colors.white;
  static const textDark = Color(0xFF1A1E2B);
  static const textMuted = Color(0xFF6B7280);
  static const border = Color(0xFFE2E5EC);
  static const danger = Color(0xFFDC3B3B);
  static const chipBackground = Color(0xFFEAF0FB);
  static const warning = Color(0xFFE67E22);
  static const warningBackground = Color(0xFFFFF4E5);
  static const warningBorder = Color(0xFFFFD9A8);
}

/// Shared gradients pulled from the SkillMatch UI prototypes.
class AppGradients {
  AppGradients._();

  static const _companyHeaderStart = Color(0xFF003486);
  static const _companyHeaderEnd = Color(0xFF0041A8);

  /// The navy gradient behind every company-side screen header.
  static const companyHeader = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [_companyHeaderStart, _companyHeaderEnd],
  );

  /// [companyHeader]'s bottom-most color, for screens where the header
  /// isn't its own fixed-height widget (e.g. [CompanyHomeScreen], where the
  /// rounded-top body sits directly on the Scaffold background) — using
  /// this as the Scaffold background keeps the sliver peeking out from the
  /// body's rounded corners matching the gradient's edge instead of some
  /// other blue.
  static const companyHeaderEnd = _companyHeaderEnd;
}

/// Manrope for headings — everything else (body copy, subtitles, labels)
/// falls through to the app-wide Inter default set on [ThemeData.fontFamily].
class AppFonts {
  AppFonts._();

  static TextStyle title({
    double fontSize = 20,
    FontWeight fontWeight = FontWeight.bold,
    Color color = AppColors.textDark,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
      ),
      // Inter is the app-wide default (body copy, subtitles, labels); titles
      // opt into Manrope explicitly via [AppFonts.title] wherever a screen
      // has a distinct heading.
      fontFamily: 'Inter',
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.textDark,
      ),
    );
  }
}
