import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Vistar Premium" design tokens — the dark portal surface used by the
/// Vistar Workspace launcher.
///
/// This is a straight port of the `:root` block in the Vistar design
/// system, so the Flutter launcher and the HTML prototypes stay visually
/// identical. The rest of the app (Productivity / Vistar Pulse) keeps its
/// light theme; the launcher is deliberately a separate, darker surface
/// that the whole app family sits on top of.
///
/// Rule of the system: the rainbow ribbon is a *thin accent*, never a
/// large fill. Big surfaces stay near-black so the ribbon pops.
class VistarPalette {
  const VistarPalette._();

  // ── Brand ribbon ────────────────────────────────────────────────
  static const Color purple = Color(0xFF7A1FB0);
  static const Color violet = Color(0xFF9B30C9);
  static const Color magenta = Color(0xFFC018C0);
  static const Color pink = Color(0xFFE0218A);
  static const Color red = Color(0xFFC8102E);
  static const Color orangeRed = Color(0xFFF0480C);
  static const Color orange = Color(0xFFF06000);
  static const Color amber = Color(0xFFF0C000);
  static const Color yellow = Color(0xFFF0E060);
  static const Color cream = Color(0xFFFFF6CC);

  /// The signature 8-stop ribbon. Reserved for primary buttons, active
  /// nav bars, KPI numerals (via [ShaderMask]) and hairline accents.
  static const List<Color> ribbonStops = <Color>[
    Color(0xFF7A1FB0),
    Color(0xFFB81FB8),
    Color(0xFFE0218A),
    Color(0xFFD11630),
    Color(0xFFF0480C),
    Color(0xFFF06000),
    Color(0xFFF0C000),
    Color(0xFFF7EE9A),
  ];

  static const List<double> _ribbonPositions = <double>[
    0.0,
    0.22,
    0.40,
    0.56,
    0.70,
    0.80,
    0.92,
    1.0,
  ];

  /// 115° ribbon — the CSS `--ribbon` token.
  static const LinearGradient ribbon = LinearGradient(
    begin: Alignment(-1.0, -0.55),
    end: Alignment(1.0, 0.55),
    colors: ribbonStops,
    stops: _ribbonPositions,
  );

  /// Horizontal variant for text shaders and thin rules.
  static const LinearGradient ribbonFlat = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: ribbonStops,
    stops: _ribbonPositions,
  );

  // ── Surfaces (near-black premium) ───────────────────────────────
  static const Color bg = Color(0xFF070611);
  static const Color bg2 = Color(0xFF0B0A18);
  static const Color surface = Color(0xFF110F1E);
  static const Color surface2 = Color(0xFF16142A);
  static const Color surface3 = Color(0xFF1D1A33);

  static const Color line = Color(0x14FFFFFF); // white @ 8%
  static const Color line2 = Color(0x21FFFFFF); // white @ 13%

  static const Color txt = Color(0xFFF2EEFB);
  static const Color txt2 = Color(0xFFB9B2D6);
  static const Color txt3 = Color(0xFF7E769B);

  static const Color ok = Color(0xFF34D399);
  static const Color warn = Color(0xFFFBBF24);
  static const Color bad = Color(0xFFFB6F84);
  static const Color info = Color(0xFF5BA8FF);

  // ── Radii ───────────────────────────────────────────────────────
  static const double rSm = 11;
  static const double r = 16;
  static const double rLg = 22;

  /// Ambient page background: three aurora glows over near-black.
  static const BoxDecoration ambient = BoxDecoration(
    color: bg,
    gradient: RadialGradient(
      center: Alignment(-0.76, -1.16),
      radius: 1.15,
      colors: <Color>[Color(0x387A1FB0), Color(0x007A1FB0)],
      stops: <double>[0.0, 0.6],
    ),
  );

  /// Soft card shadow (`--shadow`).
  static const List<BoxShadow> shadow = <BoxShadow>[
    BoxShadow(
      color: Color(0xD9000000),
      blurRadius: 60,
      spreadRadius: -28,
      offset: Offset(0, 24),
    ),
  ];

  /// Hover glow (`--glow`) — magenta bloom under a lifted card.
  static const List<BoxShadow> glow = <BoxShadow>[
    BoxShadow(
      color: Color(0x66C018C0),
      blurRadius: 50,
      spreadRadius: -22,
      offset: Offset(0, 18),
    ),
  ];
}

/// Typography: Bricolage Grotesque for display, Manrope for everything
/// else — exactly the pairing the design system specifies.
class VistarType {
  const VistarType._();

  static TextStyle display({
    required double size,
    FontWeight weight = FontWeight.w800,
    Color color = VistarPalette.txt,
    double height = 1.08,
  }) => GoogleFonts.bricolageGrotesque(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: -0.4,
  );

  static TextStyle body({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = VistarPalette.txt2,
    double height = 1.45,
    double letterSpacing = 0.1,
  }) => GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  /// Uppercase micro-label (group headers, taglines above titles).
  static TextStyle overline({
    Color color = VistarPalette.txt3,
    double size = 11,
  }) => GoogleFonts.manrope(
    fontSize: size,
    fontWeight: FontWeight.w700,
    color: color,
    letterSpacing: 2.4,
  );
}

/// Local dark [ThemeData] for the launcher. Applied with a `Theme(...)`
/// wrapper so Material widgets (inputs, chips, tooltips) pick up the
/// portal palette without disturbing the app-wide light theme.
ThemeData vistarWorkspaceTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: VistarPalette.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: VistarPalette.pink,
      onPrimary: Colors.white,
      secondary: VistarPalette.violet,
      surface: VistarPalette.surface,
      onSurface: VistarPalette.txt,
      error: VistarPalette.bad,
    ),
    textTheme: GoogleFonts.manropeTextTheme(
      base.textTheme,
    ).apply(bodyColor: VistarPalette.txt, displayColor: VistarPalette.txt),
    dividerColor: VistarPalette.line,
    splashFactory: InkSparkle.splashFactory,
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: VistarPalette.surface3,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VistarPalette.line2),
      ),
      textStyle: VistarType.body(size: 12, color: VistarPalette.txt),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VistarPalette.surface,
      hintStyle: VistarType.body(size: 14, color: VistarPalette.txt3),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VistarPalette.rSm),
        borderSide: const BorderSide(color: VistarPalette.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VistarPalette.rSm),
        borderSide: const BorderSide(color: VistarPalette.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VistarPalette.rSm),
        borderSide: BorderSide(
          color: VistarPalette.pink.withValues(alpha: 0.6),
          width: 1.4,
        ),
      ),
    ),
  );
}
