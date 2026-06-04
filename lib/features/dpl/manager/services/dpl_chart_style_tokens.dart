import 'package:flutter/material.dart';

/// Single source of truth for the Monthly DPL Chart's color palette.
///
/// Used by both the on-screen grid (Flutter widgets) and the Excel
/// exporter so the downloaded file is a 1:1 mirror of what the
/// manager sees in-app.
///
/// Hex values are ARGB (8 chars, leading FF for full alpha) — the
/// format the `excel` package expects via [ExcelColor.fromHexString].
class DplChartTokens {
  const DplChartTokens._();

  // ===== Backgrounds (ARGB hex) =====
  static const String bgHeaderBand   = 'FFDDEBF7'; // top cumulative band — light blue
  static const String bgAchHighlight = 'FFFFF2A8'; // Achievement % — soft yellow (no harsh red/yellow)
  static const String bgDateBand     = 'FFC6E0B4'; // date / day-of-week row — light green
  static const String bgTotalBand    = 'FFD9D9D9'; // per-machine Total row — grey
  static const String bgKpiBand      = 'FFFFF2CC'; // bottom KPI block accent — pale yellow
  static const String bgWeekend      = 'FFFFF2CC'; // Sat/Sun column tint — pale yellow

  // ===== Distinct shift bands (A / B / C) — each shift gets its own tint
  // so a manager can scan a column and tell at a glance which shift produced
  // a number. Picked to be print-friendly and clearly distinguishable.
  static const String bgShiftA      = 'FFDBE5F1'; // light steel blue
  static const String bgShiftB      = 'FFFCE4D6'; // light peach
  static const String bgShiftC      = 'FFE2EFDA'; // light mint green
  static const String bgShiftOther  = 'FFEAD1DC'; // fallback — pale pink (for any 4th shift)

  // ===== Fonts =====
  // The previous template used red for Plan/Actual/Downtime labels. Replaced
  // with a calm dark slate so the export is print-friendly and matches the
  // company's "no-red" rule.
  static const String fgEmphasisLabel = 'FF1F3A6E'; // dark navy slate
  static const String fgBlueLabel     = 'FF0070C0'; // secondary headings — blue
  static const String fgBlack         = 'FF000000';
  static const String fgWhite         = 'FFFFFFFF';

  // ===== Per-machine bands (rotated by machine index) — used only for the
  // machine-name column (A); the data cells use the shift bands above.
  static const List<String> machineBands = <String>[
    'FFFCE4D6', // 1st machine — light orange
    'FFDDEBF7', // 2nd machine — light blue
    'FFE2EFDA', // 3rd machine — light green
    'FFFFF2CC', // 4th — pale yellow
    'FFEAD1DC', // 5th — pale pink
    'FFD9E1F2', // 6th — pale slate blue
  ];

  /// Rotates safely — never returns out-of-bounds.
  static String machineBandAt(int index) {
    if (machineBands.isEmpty) return bgHeaderBand;
    return machineBands[index % machineBands.length];
  }

  /// Map a shift code (`A`, `B`, `C`, ...) to its band hex. Case-insensitive.
  /// Unknown codes fall back to a neutral tint so the layout never breaks.
  static String shiftColorByCode(String code) {
    final c = code.trim().toUpperCase();
    if (c == 'A') return bgShiftA;
    if (c == 'B') return bgShiftB;
    if (c == 'C') return bgShiftC;
    return bgShiftOther;
  }

  // =====================================================================
  // Flutter color helpers (consumed by the on-screen grid)
  // =====================================================================

  static Color _hex(String argbHex) {
    final v = int.parse(argbHex, radix: 16);
    return Color(v);
  }

  static Color get headerBand     => _hex(bgHeaderBand);
  static Color get achHighlight   => _hex(bgAchHighlight);
  static Color get dateBand       => _hex(bgDateBand);
  static Color get totalBand      => _hex(bgTotalBand);
  static Color get kpiBand        => _hex(bgKpiBand);
  static Color get weekendBand    => _hex(bgWeekend);
  static Color get emphasisLabel  => _hex(fgEmphasisLabel);
  static Color get blueLabel      => _hex(fgBlueLabel);
  static Color get shiftAColor    => _hex(bgShiftA);
  static Color get shiftBColor    => _hex(bgShiftB);
  static Color get shiftCColor    => _hex(bgShiftC);

  static Color shiftColorForCode(String code) => _hex(shiftColorByCode(code));

  static Color machineBandColorAt(int index) =>
      _hex(machineBandAt(index));
}
