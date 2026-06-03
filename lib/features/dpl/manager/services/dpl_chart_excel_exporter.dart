import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../models/dpl_monthly_chart.dart';
import 'dpl_chart_style_tokens.dart';

/// Client-side Excel exporter that reproduces the company's
/// "Daily Production Loading Chart" layout from a live
/// [DplMonthlyChart] payload (no server-side template needed).
///
/// The output mirrors the company's template — same row order, same
/// color bands, same red emphases, thin borders, frozen header row,
/// and column widths tuned for printing.
///
/// Layout (rows, top to bottom):
///   1. Title row                      (merged across all columns)
///   2. Cumulative summary header      — "Cumulative Till Date", running totals
///   3. Achievement summary header     — "Achievement", running %, downtime
///   4. Day-of-week header             — Mon/Tue/Wed... per column
///   5. Date header                    — day numbers per column
///   6. Per-machine block (×N machines):
///        - Shift A: Plan + Actual rows
///        - Shift B: Plan + Actual rows  (+Shift C if backend has it)
///        - Total:   Plan + Actual rows  (sums all shifts per day)
///        - Per-shift downtime rows
///   7. Bottom KPI block:
///        - Per-shift breakdown hours
///        - Per-shift manpower headcount
///        - Per-shift / per-machine lost work-hours
///        - Total Lost Work Man Hours row
///        - Per-shift / per-machine Work Man Hours
///        - Total Work Man Hours row
///        - % of lost man Hours row
class DplChartExcelExporter {
  const DplChartExcelExporter._();

  static Uint8List build(DplMonthlyChart chart) {
    if (chart.days.isEmpty) {
      throw StateError(
        'Cannot export Monthly DPL Chart — no days in the selected range.',
      );
    }

    final excel = Excel.createExcel();
    final dynamic excelDyn = excel;
    const sheetName = 'Monthly DPL Chart';

    // Replace the default "Sheet1" with our named sheet.
    String? defaultName;
    try {
      defaultName = excelDyn.getDefaultSheet() as String?;
    } catch (_) {
      defaultName = null;
    }
    if (defaultName != null && defaultName != sheetName) {
      try {
        excelDyn.rename(defaultName, sheetName);
      } catch (_) {
        excel[sheetName];
        try {
          excelDyn.delete(defaultName);
        } catch (_) {}
      }
    } else {
      excel[sheetName];
    }
    final sheet = excel[sheetName];

    final days = chart.days;
    final shifts = chart.shifts;
    final machines = chart.machines;
    final c = chart.cumulative;

    // Layout constants — left fixed columns + N day columns.
    const colMachine = 0; // "Machine Name" / "Cumulative Till Date" labels
    const colShift = 1; // "Shift A" / "Shift B" / "Total" / running stats
    const colKind = 2; // "Plan" / "Actual" / "DT (min)"
    const firstDayCol = 3; // first day-of-month column
    final lastDayCol = firstDayCol + days.length - 1;

    // Styles are built once and reused — keeps the .xlsx compact.
    final styles = _Styles();

    // Track the next row to write to — simpler than tracking absolute indices.
    var r = 0;

    // ============================================================
    // Row 0 — Title (merged across all columns)
    // ============================================================
    final titleFmt = DateFormat('MMMM yyyy');
    final title =
        'Daily Production Report - Plan Vs Actual  ${titleFmt.format(chart.from)}';
    _putText(sheet, r, colMachine, title, styles.title);
    for (var col = colMachine + 1; col <= lastDayCol; col++) {
      _putText(sheet, r, col, '', styles.title);
    }
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: colMachine, rowIndex: r),
      CellIndex.indexByColumnRow(columnIndex: lastDayCol, rowIndex: r),
    );
    sheet.setRowHeight(r, 22);
    r++;

    // ============================================================
    // Row 1 — Cumulative Till Date  + per-day cumulative Plan
    // ============================================================
    final dailyTotalPlan = <int>[];
    final dailyTotalActual = <int>[];
    for (final d in days) {
      var p = 0;
      var a = 0;
      for (final row in chart.rows) {
        for (final cell in row.daily) {
          if (_sameDay(cell.date, d)) {
            p += cell.planQty;
            a += cell.actualQty;
          }
        }
      }
      dailyTotalPlan.add(p);
      dailyTotalActual.add(a);
    }

    int runP = 0;
    int runA = 0;
    final cumPlanByDay = <int>[];
    final cumActualByDay = <int>[];
    for (var i = 0; i < days.length; i++) {
      runP += dailyTotalPlan[i];
      runA += dailyTotalActual[i];
      cumPlanByDay.add(runP);
      cumActualByDay.add(runA);
    }

    _putText(sheet, r, colMachine, 'Cumulative Till Date', styles.headerLabel);
    _putText(sheet, r, colShift, '${c.actualQty} / ${c.planQty}',
        styles.headerHighlight);
    _putText(sheet, r, colKind, 'Cum. Plan', styles.headerLabel);
    for (var i = 0; i < days.length; i++) {
      _putInt(sheet, r, firstDayCol + i, cumPlanByDay[i], styles.headerData);
    }
    r++;

    final achievement = (c.achievementPct * 100);
    _putText(sheet, r, colMachine, 'Achievement', styles.headerLabel);
    _putText(sheet, r, colShift, '${achievement.toStringAsFixed(1)}%',
        styles.headerHighlight);
    _putText(sheet, r, colKind, 'Cum. Actual', styles.headerLabel);
    for (var i = 0; i < days.length; i++) {
      _putInt(sheet, r, firstDayCol + i, cumActualByDay[i], styles.headerData);
    }
    r++;

    // ============================================================
    // Row 3 — Day-of-week header   (e.g. Fri Sat Sun Mon ...)
    // ============================================================
    final dowFmt = DateFormat('EEE');
    _putText(sheet, r, colMachine, '', styles.dateBandLabel);
    _putText(sheet, r, colShift, 'Day', styles.dateBandLabel);
    _putText(sheet, r, colKind, '', styles.dateBandLabel);
    for (var i = 0; i < days.length; i++) {
      _putText(
        sheet,
        r,
        firstDayCol + i,
        dowFmt.format(days[i]),
        styles.dateBandCell,
      );
    }
    r++;

    // Row 4 — Date numbers row
    _putText(sheet, r, colMachine, 'Machine', styles.dateBandLabel);
    _putText(sheet, r, colShift, 'Shift', styles.dateBandLabel);
    _putText(sheet, r, colKind, 'Date', styles.dateBandLabel);
    for (var i = 0; i < days.length; i++) {
      _putInt(sheet, r, firstDayCol + i, days[i].day, styles.dateBandCell);
    }
    r++;

    // ============================================================
    // Per-machine sections
    // ============================================================
    for (var mIdx = 0; mIdx < machines.length; mIdx++) {
      final machine = machines[mIdx];
      final machineRows =
          chart.rows.where((r) => r.machineId == machine.id).toList();
      final bandHex = DplChartTokens.machineBandAt(mIdx);
      final bandCellStyle = styles.bandedCell(bandHex);
      final bandPlanLabel = styles.bandedRedLabel(bandHex);
      final bandActualLabel = styles.bandedLabel(bandHex);
      final bandMachineLabel = styles.bandedMachineLabel(bandHex);

      // Per-day Plan / Actual per shift
      for (final shift in shifts) {
        final row = _findRow(machineRows, machine.id, shift.id);

        // Plan row
        _putText(sheet, r, colMachine, 'Machine Name: ${machine.name}',
            bandMachineLabel);
        _putText(sheet, r, colShift, 'Shift ${shift.code}', bandActualLabel);
        _putText(sheet, r, colKind, 'Plan', bandPlanLabel);
        for (var i = 0; i < days.length; i++) {
          final cell = _cellOn(row, days[i]);
          _putInt(sheet, r, firstDayCol + i, cell?.planQty ?? 0, bandCellStyle);
        }
        r++;

        // Actual row
        _putText(sheet, r, colMachine, '', bandMachineLabel);
        _putText(sheet, r, colShift, '', bandActualLabel);
        _putText(sheet, r, colKind, 'Actual', bandActualLabel);
        for (var i = 0; i < days.length; i++) {
          final cell = _cellOn(row, days[i]);
          _putInt(sheet, r, firstDayCol + i, cell?.actualQty ?? 0,
              bandCellStyle);
        }
        r++;
      }

      // Totals (sum across shifts) per day
      final totalPlanByDay = <int>[];
      final totalActualByDay = <int>[];
      for (final d in days) {
        var p = 0;
        var a = 0;
        for (final row in machineRows) {
          for (final cell in row.daily) {
            if (_sameDay(cell.date, d)) {
              p += cell.planQty;
              a += cell.actualQty;
            }
          }
        }
        totalPlanByDay.add(p);
        totalActualByDay.add(a);
      }

      _putText(sheet, r, colMachine, '', styles.totalLabel);
      _putText(sheet, r, colShift, 'Total', styles.totalLabel);
      _putText(sheet, r, colKind, 'Plan', styles.totalRedLabel);
      for (var i = 0; i < days.length; i++) {
        _putInt(sheet, r, firstDayCol + i, totalPlanByDay[i], styles.totalCell);
      }
      r++;

      _putText(sheet, r, colMachine, '', styles.totalLabel);
      _putText(sheet, r, colShift, '', styles.totalLabel);
      _putText(sheet, r, colKind, 'Actual', styles.totalLabel);
      for (var i = 0; i < days.length; i++) {
        _putInt(sheet, r, firstDayCol + i, totalActualByDay[i],
            styles.totalCell);
      }
      r++;

      // Per-shift downtime rows for this machine
      for (final shift in shifts) {
        final row = _findRow(machineRows, machine.id, shift.id);

        _putText(sheet, r, colMachine, '', bandMachineLabel);
        _putText(sheet, r, colShift, '${shift.code}-shift Down Time in Minutes',
            bandActualLabel);
        _putText(sheet, r, colKind, '', bandPlanLabel);
        for (var i = 0; i < days.length; i++) {
          final cell = _cellOn(row, days[i]);
          _putInt(sheet, r, firstDayCol + i, cell?.downtimeMinutes ?? 0,
              bandCellStyle);
        }
        r++;
      }
    }

    // Small spacer row before the KPI block
    r++;

    // ============================================================
    // Bottom block — per-shift breakdown hours, headcount, lost MH
    // ============================================================

    double breakdownHoursFor(DateTime date, int shiftId) {
      var sum = 0.0;
      for (final b in chart.breakdownHours) {
        if (b.shiftId != shiftId) continue;
        if (!_sameDay(b.date, date)) continue;
        sum += b.hours;
      }
      return sum;
    }

    double breakdownHoursForMachine(
      DateTime date,
      int shiftId,
      int machineId,
    ) {
      var sum = 0.0;
      for (final b in chart.breakdownHours) {
        if (b.shiftId != shiftId) continue;
        if (!_sameDay(b.date, date)) continue;
        sum += b.byMachine[machineId] ?? 0;
      }
      return sum;
    }

    int headcountFor(DateTime date, int shiftId) {
      var sum = 0;
      for (final m in chart.manpower) {
        if (m.shiftId != shiftId) continue;
        if (!_sameDay(m.date, date)) continue;
        sum += m.headcount;
      }
      return sum;
    }

    for (final shift in shifts) {
      final shiftLabel = '${shift.code}-shift';

      // Breakdown hours (total)
      _putText(sheet, r, colMachine, 'Breakdown Hours', styles.kpiLabel);
      _putText(sheet, r, colShift, shiftLabel, styles.kpiLabel);
      _putText(sheet, r, colKind, '', styles.kpiLabel);
      for (var i = 0; i < days.length; i++) {
        _putDouble(
          sheet,
          r,
          firstDayCol + i,
          _round1(breakdownHoursFor(days[i], shift.id)),
          styles.kpiDecimalCell,
        );
      }
      r++;

      // No. of Manpower
      _putText(sheet, r, colMachine, 'No. of Manpower', styles.kpiLabel);
      _putText(sheet, r, colShift, shiftLabel, styles.kpiLabel);
      _putText(sheet, r, colKind, '', styles.kpiLabel);
      for (var i = 0; i < days.length; i++) {
        _putInt(
          sheet,
          r,
          firstDayCol + i,
          headcountFor(days[i], shift.id),
          styles.kpiIntCell,
        );
      }
      r++;

      // Per-machine lost work-man-hours = breakdown hours × headcount
      for (var mIdx = 0; mIdx < machines.length; mIdx++) {
        final machine = machines[mIdx];
        final bandHex = DplChartTokens.machineBandAt(mIdx);

        _putText(
          sheet,
          r,
          colMachine,
          '${machine.name} lost Work Man Hours',
          styles.bandedKpiLabel(bandHex),
        );
        _putText(sheet, r, colShift, shiftLabel, styles.bandedKpiLabel(bandHex));
        _putText(sheet, r, colKind, '', styles.bandedKpiLabel(bandHex));
        for (var i = 0; i < days.length; i++) {
          final br = breakdownHoursForMachine(days[i], shift.id, machine.id);
          final hc = headcountFor(days[i], shift.id);
          _putDouble(
            sheet,
            r,
            firstDayCol + i,
            _round1(br * hc),
            styles.bandedKpiDecimalCell(bandHex),
          );
        }
        r++;
      }
    }

    // Total lost work-man-hours per day (sum across shifts and machines)
    _putText(sheet, r, colMachine, 'Total Lost Work Man Hours Due to Breakdown',
        styles.totalLabel);
    _putText(sheet, r, colShift, '', styles.totalLabel);
    _putText(sheet, r, colKind, '', styles.totalLabel);
    for (var i = 0; i < days.length; i++) {
      var totalLost = 0.0;
      for (final shift in shifts) {
        final hc = headcountFor(days[i], shift.id);
        for (final machine in machines) {
          final br =
              breakdownHoursForMachine(days[i], shift.id, machine.id);
          totalLost += br * hc;
        }
      }
      _putDouble(
        sheet,
        r,
        firstDayCol + i,
        _round1(totalLost),
        styles.totalDecimalCell,
      );
    }
    r++;

    // Per-shift / per-machine Work Man Hours = headcount × 8h (equal split)
    for (final shift in shifts) {
      for (var mIdx = 0; mIdx < machines.length; mIdx++) {
        final machine = machines[mIdx];
        final bandHex = DplChartTokens.machineBandAt(mIdx);

        _putText(
          sheet,
          r,
          colMachine,
          '${machine.name} Work Man Hours',
          styles.bandedKpiLabel(bandHex),
        );
        _putText(sheet, r, colShift, '${shift.code}-shift',
            styles.bandedKpiLabel(bandHex));
        _putText(sheet, r, colKind, '', styles.bandedKpiLabel(bandHex));
        for (var i = 0; i < days.length; i++) {
          final hc = headcountFor(days[i], shift.id);
          final share = machines.isEmpty ? hc : (hc / machines.length);
          _putDouble(
            sheet,
            r,
            firstDayCol + i,
            _round1(share * 8),
            styles.bandedKpiDecimalCell(bandHex),
          );
        }
        r++;
      }
    }

    // Total Work Man Hours per day
    _putText(
        sheet, r, colMachine, 'Total Work Man Hours', styles.totalLabel);
    _putText(sheet, r, colShift, '', styles.totalLabel);
    _putText(sheet, r, colKind, '', styles.totalLabel);
    for (var i = 0; i < days.length; i++) {
      var totalMh = 0.0;
      for (final shift in shifts) {
        totalMh += headcountFor(days[i], shift.id) * 8;
      }
      _putDouble(
        sheet,
        r,
        firstDayCol + i,
        _round1(totalMh),
        styles.totalDecimalCell,
      );
    }
    r++;

    // % of lost man hours per day
    _putText(
        sheet, r, colMachine, '% of lost man Hours', styles.headerLabel);
    _putText(sheet, r, colShift, '', styles.headerLabel);
    _putText(sheet, r, colKind, '', styles.headerLabel);
    for (var i = 0; i < days.length; i++) {
      var totalMh = 0.0;
      var totalLost = 0.0;
      for (final shift in shifts) {
        final hc = headcountFor(days[i], shift.id);
        totalMh += hc * 8;
        for (final machine in machines) {
          final br =
              breakdownHoursForMachine(days[i], shift.id, machine.id);
          totalLost += br * hc;
        }
      }
      if (totalMh <= 0) {
        _putText(sheet, r, firstDayCol + i, '—', styles.headerHighlight);
      } else {
        final pct = totalLost / totalMh;
        _putDouble(
          sheet,
          r,
          firstDayCol + i,
          double.parse(pct.toStringAsFixed(4)),
          styles.headerHighlightPct,
        );
      }
    }
    r++;

    // ============================================================
    // Column widths + frozen header row
    // ============================================================
    sheet.setColumnWidth(colMachine, 32);
    sheet.setColumnWidth(colShift, 14);
    sheet.setColumnWidth(colKind, 10);
    for (var i = 0; i < days.length; i++) {
      sheet.setColumnWidth(firstDayCol + i, 6.5);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Failed to encode Excel file.');
    }
    return Uint8List.fromList(encoded);
  }

  // ===== Internal helpers =====

  static void _putText(
    Sheet sheet,
    int row,
    int col,
    String value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = TextCellValue(value);
    cell.cellStyle = style;
  }

  static void _putInt(
    Sheet sheet,
    int row,
    int col,
    int value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = IntCellValue(value);
    cell.cellStyle = style;
  }

  static void _putDouble(
    Sheet sheet,
    int row,
    int col,
    double value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = DoubleCellValue(value);
    cell.cellStyle = style;
  }

  static double _round1(double v) =>
      double.parse(v.toStringAsFixed(1));

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DplChartRow _findRow(
    List<DplChartRow> rows,
    int machineId,
    int shiftId,
  ) {
    for (final row in rows) {
      if (row.machineId == machineId && row.shiftId == shiftId) return row;
    }
    return DplChartRow(
      machineId: machineId,
      shiftId: shiftId,
      daily: const [],
      totals: DplChartTotals.empty(),
    );
  }

  static DplChartCell? _cellOn(DplChartRow row, DateTime d) {
    for (final c in row.daily) {
      if (_sameDay(c.date, d)) return c;
    }
    return null;
  }
}

/// All pre-built [CellStyle] objects, grouped here so the
/// builder above stays focused on layout, not formatting.
class _Styles {
  // Thin black border on all 4 sides — matches the template.
  static Border get _thin =>
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);

  static CellStyle _bordered({
    required ExcelColor bg,
    ExcelColor? fg,
    bool bold = false,
    int? fontSize,
    HorizontalAlign h = HorizontalAlign.Center,
    VerticalAlign v = VerticalAlign.Center,
    TextWrapping? wrap,
    NumFormat? numberFormat,
  }) {
    return CellStyle(
      backgroundColorHex: bg,
      fontColorHex: fg ?? ExcelColor.black,
      bold: bold,
      fontSize: fontSize,
      horizontalAlign: h,
      verticalAlign: v,
      textWrapping: wrap,
      leftBorder: _thin,
      rightBorder: _thin,
      topBorder: _thin,
      bottomBorder: _thin,
      numberFormat: numberFormat ?? NumFormat.standard_0,
    );
  }

  late final CellStyle title = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgHeaderBand),
    bold: true,
    fontSize: 14,
  );

  late final CellStyle headerLabel = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgHeaderBand),
    bold: true,
    fontSize: 11,
    h: HorizontalAlign.Left,
    wrap: TextWrapping.WrapText,
  );

  late final CellStyle headerHighlight = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgAchHighlight),
    bold: true,
    fontSize: 11,
  );

  late final CellStyle headerHighlightPct = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgAchHighlight),
    bold: true,
    numberFormat: NumFormat.standard_10, // 0.00%
  );

  late final CellStyle headerData = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgHeaderBand),
    bold: true,
  );

  late final CellStyle dateBandLabel = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgDateBand),
    bold: true,
    h: HorizontalAlign.Left,
  );

  late final CellStyle dateBandCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgDateBand),
    bold: true,
  );

  late final CellStyle totalLabel = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    bold: true,
    h: HorizontalAlign.Left,
    wrap: TextWrapping.WrapText,
  );

  late final CellStyle totalRedLabel = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    fg: ExcelColor.fromHexString(DplChartTokens.fgRedLabel),
    bold: true,
  );

  late final CellStyle totalCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    bold: true,
  );

  late final CellStyle totalDecimalCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    bold: true,
    numberFormat: NumFormat.custom(formatCode: '0.0'),
  );

  late final CellStyle kpiLabel = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgKpiBand),
    bold: true,
    h: HorizontalAlign.Left,
    wrap: TextWrapping.WrapText,
  );

  late final CellStyle kpiIntCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgKpiBand),
  );

  late final CellStyle kpiDecimalCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgKpiBand),
    numberFormat: NumFormat.custom(formatCode: '0.0'),
  );

  // Per-machine band styles are built on demand (cached) since the
  // machine count is unbounded.
  final Map<String, CellStyle> _bandCellCache = {};
  final Map<String, CellStyle> _bandLabelCache = {};
  final Map<String, CellStyle> _bandRedLabelCache = {};
  final Map<String, CellStyle> _bandMachineLabelCache = {};
  final Map<String, CellStyle> _bandKpiLabelCache = {};
  final Map<String, CellStyle> _bandKpiDecimalCache = {};

  CellStyle bandedCell(String hex) => _bandCellCache.putIfAbsent(
        hex,
        () => _bordered(bg: ExcelColor.fromHexString(hex)),
      );

  CellStyle bandedLabel(String hex) => _bandLabelCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          bold: true,
        ),
      );

  CellStyle bandedRedLabel(String hex) => _bandRedLabelCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          fg: ExcelColor.fromHexString(DplChartTokens.fgRedLabel),
          bold: true,
        ),
      );

  CellStyle bandedMachineLabel(String hex) =>
      _bandMachineLabelCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          bold: true,
          h: HorizontalAlign.Left,
          wrap: TextWrapping.WrapText,
        ),
      );

  CellStyle bandedKpiLabel(String hex) => _bandKpiLabelCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          bold: true,
          h: HorizontalAlign.Left,
          wrap: TextWrapping.WrapText,
        ),
      );

  CellStyle bandedKpiDecimalCell(String hex) =>
      _bandKpiDecimalCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          numberFormat: NumFormat.custom(formatCode: '0.0'),
        ),
      );
}
