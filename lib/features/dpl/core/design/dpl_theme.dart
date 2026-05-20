import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Vistar DPL design system.
///
/// Every color, font, spacing, radius, and shadow used in DPL screens
/// comes from here. Hard-coded hex values in screen files are a code
/// smell — search the codebase periodically and pull violations back
/// into this file.

class DplColors {
  const DplColors._();

  // Brand — single primary purple anchored by the Vistar swoosh.
  static const Color primary = Color(0xFF6B1F8C);
  static const Color primaryLight = Color(0xFF8B3FAC);
  static const Color primaryDark = Color(0xFF4A1163);
  static const Color primaryTint = Color(0xFFF3E8F9);

  // Gradient accent — magenta → orange → yellow ribbon. Use only for
  // hero CTAs (Submit, START, completion rings, login button), never
  // as a large surface.
  static const List<Color> gradientStops = [
    Color(0xFFA4257A),
    Color(0xFFE54B2A),
    Color(0xFFF5A623),
  ];
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: gradientStops,
  );

  // Semantic — pairs of foreground + soft tint background.
  static const Color success = Color(0xFF15803D);
  static const Color successBg = Color(0xFFE6F4EA);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF2563EB);
  static const Color infoBg = Color(0xFFDBEAFE);
  static const Color neutral = Color(0xFF6B7280);
  static const Color neutralBg = Color(0xFFF3F4F6);

  // Status pills (plan / item status colors).
  static const Color statusDraft = Color(0xFF6B7280);
  static const Color statusPublished = Color(0xFF2563EB);
  static const Color statusInProgress = Color(0xFFD97706);
  static const Color statusCompleted = Color(0xFF15803D);
  static const Color statusLocked = Color(0xFF4B5563);

  // Surfaces.
  static const Color pageBg = Color(0xFFF8F7FB);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE5E7EB);

  // Text.
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);
}

class DplSpacing {
  const DplSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
}

class DplRadius {
  const DplRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double pill = 999;
}

class DplShadows {
  const DplShadows._();

  /// Soft 2-layer card shadow.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 6),
    ),
  ];

  /// Stronger shadow for bottom sheets / modals.
  static const List<BoxShadow> sheet = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, -2),
    ),
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, -8),
    ),
  ];

  /// Top shadow for the bottom navigation bar.
  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 6,
      offset: Offset(0, -2),
    ),
  ];

  /// Subtle button drop shadow.
  static const List<BoxShadow> button = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
}

/// Typography scale. All number styles enable tabular figures so
/// digits align cleanly in tables and cards.
class DplText {
  const DplText._();

  static const _tabularFigures = FontFeature.tabularFigures();

  // UI font — Inter via google_fonts.
  static TextStyle _inter({
    required double size,
    required FontWeight weight,
    double? height,
    Color? color,
    List<FontFeature> features = const [],
  }) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? DplColors.textPrimary,
        fontFeatures: features,
      );

  static TextStyle _mono({
    required double size,
    required FontWeight weight,
    double? height,
    Color? color,
  }) =>
      GoogleFonts.robotoMono(
        fontSize: size,
        fontWeight: weight,
        height: height,
        color: color ?? DplColors.textPrimary,
        fontFeatures: const [_tabularFigures],
      );

  static TextStyle display() => _inter(size: 32, weight: FontWeight.w800);
  static TextStyle h1() => _inter(size: 24, weight: FontWeight.w800);
  static TextStyle h2() => _inter(size: 20, weight: FontWeight.w800);
  static TextStyle h3() =>
      _inter(size: 17, weight: FontWeight.w700, height: 1.3);
  static TextStyle bodyLg() => _inter(size: 16, weight: FontWeight.w500);
  static TextStyle body() => _inter(size: 14, weight: FontWeight.w500);
  static TextStyle bodySm() => _inter(size: 13, weight: FontWeight.w500);
  static TextStyle caption() => _inter(
        size: 12,
        weight: FontWeight.w600,
        color: DplColors.textSecondary,
      );
  static TextStyle button() =>
      _inter(size: 15, weight: FontWeight.w700, color: DplColors.textInverse);
  static TextStyle mono() => _mono(size: 16, weight: FontWeight.w600);
  static TextStyle numLg() => _inter(
        size: 28,
        weight: FontWeight.w800,
        features: const [_tabularFigures],
      );
  static TextStyle numMd() => _inter(
        size: 20,
        weight: FontWeight.w800,
        features: const [_tabularFigures],
      );
  static TextStyle timer() => _mono(size: 48, weight: FontWeight.w700);
}

/// Returns a [ThemeData] tuned for DPL surfaces. Apply via `Theme(...)`
/// at the top of each DPL shell, or push it into MaterialApp directly.
ThemeData dplThemeData() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: DplColors.pageBg,
    colorScheme: base.colorScheme.copyWith(
      primary: DplColors.primary,
      onPrimary: DplColors.textInverse,
      surface: DplColors.cardBg,
      onSurface: DplColors.textPrimary,
      error: DplColors.error,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: DplColors.textPrimary,
      displayColor: DplColors.textPrimary,
    ),
    dividerColor: DplColors.divider,
    splashFactory: InkSparkle.splashFactory,
  );
}
