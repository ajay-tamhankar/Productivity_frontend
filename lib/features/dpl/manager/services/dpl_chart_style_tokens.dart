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
  static const String bgAchHighlight = 'FFFFFF00'; // Achievement % — bright yellow
  static const String bgDateBand     = 'FFC6E0B4'; // date / day-of-week row — light green
  static const String bgTotalBand    = 'FFD9D9D9'; // per-machine Total row — grey
  static const String bgKpiBand      = 'FFFFF2CC'; // bottom KPI block accent — pale yellow
  static const String bgWeekend      = 'FFFFF2CC'; // Sat/Sun column tint — pale yellow

  // ===== Fonts =====
  static const String fgRedLabel     = 'FFFF0000'; // Plan / Actual / Downtime labels — red
  static const String fgBlueLabel    = 'FF0070C0'; // secondary headings — blue
  static const String fgBlack        = 'FF000000';
  static const String fgWhite        = 'FFFFFFFF';

  // ===== Per-machine bands (rotated by machine index) =====
  static const List<String> machineBands = <String>[
    'FFFCE4D6', // 1st machine (Nexon SR) — light orange
    'FFDDEBF7', // 2nd machine (Nexon PR) — light blue
    'FFE2EFDA', // 3rd machine (X0 HL)    — light green
    'FFFFF2CC', // 4th — pale yellow
    'FFEAD1DC', // 5th — pale pink
    'FFD9E1F2', // 6th — pale slate blue
  ];

  /// Rotates safely — never returns out-of-bounds.
  static String machineBandAt(int index) {
    if (machineBands.isEmpty) return bgHeaderBand;
    return machineBands[index % machineBands.length];
  }

  // =====================================================================
  // Flutter color helpers (consumed by the on-screen grid)
  // =====================================================================

  static Color _hex(String argbHex) {
    final v = int.parse(argbHex, radix: 16);
    return Color(v);
  }

  static Color get headerBand   => _hex(bgHeaderBand);
  static Color get achHighlight => _hex(bgAchHighlight);
  static Color get dateBand     => _hex(bgDateBand);
  static Color get totalBand    => _hex(bgTotalBand);
  static Color get kpiBand      => _hex(bgKpiBand);
  static Color get weekendBand  => _hex(bgWeekend);
  static Color get redLabel     => _hex(fgRedLabel);
  static Color get blueLabel    => _hex(fgBlueLabel);

  static Color machineBandColorAt(int index) =>
      _hex(machineBandAt(index));
}
