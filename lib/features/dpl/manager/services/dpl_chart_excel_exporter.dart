import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../models/dpl_monthly_chart.dart';
import 'dpl_chart_style_tokens.dart';

/// Client-side Excel exporter that reproduces the company's
/// "Daily Production Loading Chart" layout from a live
/// [DplMonthlyChart] payload (no server-side template needed).
///
/// Layout (rows, top to bottom):
///   1. Title row                      (merged across all columns)
///   2. "Cumulative Till Date" header  — Cum. Plan + per-day cum totals (formula)
///   3. "Achievement" header           — % achievement (formula) + Cum. Actual
///   4. Day-of-week header             — Mon/Tue/Wed... per column
///   5. Date header                    — day numbers per column + "Cum Till Date" label
///   6. Per-machine block (×N machines, 11 rows each when 3 shifts):
///        - Shift A: Plan + Actual rows   (shift-A tinted)
///        - Shift B: Plan + Actual rows   (shift-B tinted)
///        - Shift C: Plan + Actual rows   (shift-C tinted)
///        - Total:   Plan + Actual rows   (grey, formula = sum of shifts)
///        - Per-shift downtime rows       (shift-tinted, minutes)
///        Column A is merged across the whole block (machine name).
///        Column B is merged across each Plan/Actual pair (shift label).
///   7. Bottom KPI block:
///        - Per-shift breakdown hours / manpower count
///        - Per-shift / per-machine lost work-hours
///        - Total Lost Work Man Hours
///        - Per-shift / per-machine Work Man Hours
///        - Total Work Man Hours
///        - % of lost man hours
///
/// All numeric "Cum Till Date" cells in column D are emitted as `SUM(E:H)`
/// formulas so the spreadsheet stays live if a manager edits day values.
/// Top "Cumulative" rows reference each machine's Total rows by absolute
/// cell address, again so edits cascade automatically.
///
/// A freeze pane (4 left cols + 5 top rows) is injected into the saved
/// XML — the `excel` package doesn't expose it directly, so we patch the
/// emitted zip after `excel.encode()`.
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
    // Sort shifts by code so the layout is deterministic (A → B → C).
    final shifts = [...chart.shifts]
      ..sort((a, b) => a.code.toUpperCase().compareTo(b.code.toUpperCase()));
    final machines = chart.machines;

    // Column layout (0-indexed). Excel letters in comments.
    const colMachine = 0;     // A
    const colShift = 1;       // B
    const colKind = 2;        // C
    const colCum = 3;         // D — NEW "Cum Till Date" column
    const firstDayCol = 4;    // E
    final lastDayCol = firstDayCol + days.length - 1;

    final styles = _Styles();

    // 0-indexed row pointer used while writing. Excel rows are 1-indexed
    // so anywhere we build a formula we use `excelRow = r + 1`.
    var r = 0;

    // ============================================================
    // Row 1 — Title (merged across all columns)
    // ============================================================
    final titleText =
        'Daily Production Report - Plan Vs Actual  ${DateFormat('MMMM yyyy').format(chart.from)}';
    _putText(sheet, r, colMachine, titleText, styles.title);
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
    // Row 2 — "Particulars" / "Actual / Plan" header for the
    //          compact "as-of" snapshot block (A2/B2).
    // Row 3 — `TODAY()-1` (formatted "d-mmm") + a formula that looks up
    //          that day's column in the date-numbers row (row 7) and
    //          concatenates "actual / plan" from the per-day cumulative
    //          rows. Stays live — if the user opens the file the next
    //          day or edits a day cell, A3/B3 recompute automatically.
    //          IFERROR ➜ "—" when TODAY()-1 falls outside the range so
    //          historical exports don't show #N/A.
    // ============================================================
    _putText(sheet, r, colMachine, 'Particulars', styles.headerLabel);
    _putText(sheet, r, colShift, 'Actual / Plan', styles.headerLabel);
    _putText(sheet, r, colKind, '', styles.headerLabel);
    _putText(sheet, r, colCum, '', styles.headerLabel);
    sheet.setRowHeight(r, 22);
    r++;

    // 1-indexed Excel row positions used in the lookup formula. Their
    // order is hard-coded by the layout above, so this is safe.
    const cumPlanRowExcel = 4;     // "Cumulative Till Date" — per-day plan totals
    const cumActualRowExcel = 5;   // "Achievement"          — per-day actual totals
    const dateNumRowExcel = 7;     // "Date" header          — day-of-month numbers
    final firstDayLetter = _col(firstDayCol);
    final lastDayLetter = _col(lastDayCol);
    final dayRange =
        '$firstDayLetter$dateNumRowExcel:$lastDayLetter$dateNumRowExcel';
    final planRange =
        '$firstDayLetter$cumPlanRowExcel:$lastDayLetter$cumPlanRowExcel';
    final actualRange =
        '$firstDayLetter$cumActualRowExcel:$lastDayLetter$cumActualRowExcel';
    // Date row holds full date serials (rendered "dd-mmm"), so we match
    // TODAY()-1 directly without extracting the day-of-month.
    final matchExpr = 'MATCH(TODAY()-1,$dayRange,0)';
    final snapshotFormula =
        'IFERROR(INDEX($actualRange,1,$matchExpr)&" / "&INDEX($planRange,1,$matchExpr),"—")';

    // Use TEXT() so the result is a string ("3-Jun") rather than a date
    // serial. The `excel` package only emits an explicit horizontal
    // alignment when it differs from `Left`, so a date cell would otherwise
    // fall back to Excel's right-align-numbers default and look out of
    // line with the other labels in this column.
    _putFormula(sheet, r, colMachine, 'TEXT(TODAY()-1,"d-mmm")',
        styles.headerLabel);
    _putFormula(sheet, r, colShift, snapshotFormula, styles.headerHighlight);
    _putText(sheet, r, colKind, '', styles.headerLabel);
    _putText(sheet, r, colCum, '', styles.headerLabel);
    sheet.setRowHeight(r, 22);
    r++;

    // ============================================================
    // Row 4 — "Cumulative Till Date" + Cum. Plan
    // Row 5 — "Achievement"          + Cum. Actual
    // (Formulas filled in *after* per-machine blocks so we know which
    // Excel rows are the per-machine Total rows.)
    // ============================================================
    final cumPlanRowR = r;
    _putText(sheet, r, colMachine, 'Cumulative Till Date', styles.headerLabel);
    // B4 = D5 & " / " & D4 — string concat of the cumulative actual and
    // cumulative plan that the per-machine Total rows feed into below.
    // Keeps the headline KPI live without hard-coding the API value.
    _putFormula(
      sheet,
      r,
      colShift,
      'D${r + 2}&" / "&D${r + 1}',
      styles.headerHighlight,
    );
    _putText(sheet, r, colKind, 'Cum. Plan', styles.headerLabel);
    // colCum + day cols filled later via _putFormula.
    sheet.setRowHeight(r, 24);
    r++;

    final cumActualRowR = r;
    _putText(sheet, r, colMachine, 'Achievement', styles.headerLabel);
    // colShift gets B-row formula (=D{cumActual}/D{cumPlan}) later.
    _putText(sheet, r, colKind, 'Cum. Actual', styles.headerLabel);
    sheet.setRowHeight(r, 24);
    r++;

    // ============================================================
    // Row 4 — Day-of-week header (Mon/Tue/Wed...)
    // Row 5 — Date numbers row
    // ============================================================
    final dowFmt = DateFormat('EEE');
    _putText(sheet, r, colMachine, '', styles.dateBandLabel);
    _putText(sheet, r, colShift, 'Day', styles.dateBandLabel);
    _putText(sheet, r, colKind, '', styles.dateBandLabel);
    _putText(sheet, r, colCum, '', styles.dateBandLabel);
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

    _putText(sheet, r, colMachine, 'Machine', styles.dateBandLabel);
    _putText(sheet, r, colShift, 'Shift', styles.dateBandLabel);
    _putText(sheet, r, colKind, 'Date', styles.dateBandLabel);
    _putText(sheet, r, colCum, 'Cum Till Date', styles.dateBandLabel);
    for (var i = 0; i < days.length; i++) {
      // Store the full date as a serial; the `dd-mmm` format on the cell
      // renders it as "01-Jun" while keeping it match-able against
      // `TODAY()-1` from the snapshot formula above.
      _putDate(sheet, r, firstDayCol + i, days[i], styles.dateBandDateCell);
    }
    r++;

    // ============================================================
    // Per-machine blocks
    // ============================================================
    // Excel-row positions of each machine's "Total Plan" and "Total Actual"
    // rows — used to build the top-of-sheet Cumulative formulas.
    final totalPlanRowsExcel = <int>[];
    final totalActualRowsExcel = <int>[];

    for (var mIdx = 0; mIdx < machines.length; mIdx++) {
      final machine = machines[mIdx];
      final machineRows =
          chart.rows.where((row) => row.machineId == machine.id).toList();
      final machineBandHex = DplChartTokens.machineBandAt(mIdx);
      final machineCellStyle = styles.machineNameCell(machineBandHex);

      final blockStartR = r;
      final blockStartExcel = blockStartR + 1;

      // ---- Per-shift Plan + Actual pairs --------------------------------
      for (var sIdx = 0; sIdx < shifts.length; sIdx++) {
        final shift = shifts[sIdx];
        final shiftHex = DplChartTokens.shiftColorByCode(shift.code);
        final row = _findRow(machineRows, machine.id, shift.id);

        // Plan row
        final planR = r;
        final planExcel = planR + 1;
        _putText(sheet, planR, colMachine, '', machineCellStyle);
        _putText(sheet, planR, colShift, 'Shift ${shift.code}',
            styles.shiftLabel(shiftHex));
        _putText(sheet, planR, colKind, 'Plan', styles.shiftKindLabel(shiftHex));
        _putFormula(
          sheet,
          planR,
          colCum,
          'SUM(${_col(firstDayCol)}$planExcel:${_col(lastDayCol)}$planExcel)',
          styles.shiftCumCell(shiftHex),
        );
        for (var i = 0; i < days.length; i++) {
          final cell = _cellOn(row, days[i]);
          _putInt(sheet, planR, firstDayCol + i, cell?.planQty ?? 0,
              styles.shiftCell(shiftHex));
        }
        r++;

        // Actual row
        final actR = r;
        final actExcel = actR + 1;
        _putText(sheet, actR, colMachine, '', machineCellStyle);
        _putText(sheet, actR, colShift, '', styles.shiftLabel(shiftHex));
        _putText(sheet, actR, colKind, 'Actual', styles.shiftKindLabel(shiftHex));
        _putFormula(
          sheet,
          actR,
          colCum,
          'SUM(${_col(firstDayCol)}$actExcel:${_col(lastDayCol)}$actExcel)',
          styles.shiftCumCell(shiftHex),
        );
        for (var i = 0; i < days.length; i++) {
          final cell = _cellOn(row, days[i]);
          _putInt(sheet, actR, firstDayCol + i, cell?.actualQty ?? 0,
              styles.shiftCell(shiftHex));
        }
        r++;

        // Merge B column across this Plan+Actual pair so the shift label
        // spans both rows visually (matches the company template).
        sheet.merge(
          CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: planR),
          CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: actR),
        );
      }

      // ---- Total Plan + Actual (formula sum of shift rows) ---------------
      final totalPlanR = r;
      final totalPlanExcel = totalPlanR + 1;
      totalPlanRowsExcel.add(totalPlanExcel);
      _putText(sheet, totalPlanR, colMachine, '', machineCellStyle);
      _putText(sheet, totalPlanR, colShift, 'Total', styles.totalLabel);
      _putText(sheet, totalPlanR, colKind, 'Plan', styles.totalKindLabel);
      // D{totalPlan} = D{shiftAPlan} + D{shiftBPlan} + D{shiftCPlan}
      final totalPlanDFormula = List.generate(shifts.length, (i) {
        final shiftPlanExcel = blockStartExcel + (i * 2); // every 2 rows
        return 'D$shiftPlanExcel';
      }).join('+');
      _putFormula(sheet, totalPlanR, colCum, totalPlanDFormula,
          styles.totalCumCell);
      for (var i = 0; i < days.length; i++) {
        final colLetter = _col(firstDayCol + i);
        // Per-day total = sum of each shift's Plan for that column.
        final dayFormula = List.generate(shifts.length, (j) {
          final shiftPlanExcel = blockStartExcel + (j * 2);
          return '$colLetter$shiftPlanExcel';
        }).join('+');
        _putFormula(sheet, totalPlanR, firstDayCol + i, dayFormula,
            styles.totalCell);
      }
      r++;

      final totalActR = r;
      final totalActExcel = totalActR + 1;
      totalActualRowsExcel.add(totalActExcel);
      _putText(sheet, totalActR, colMachine, '', machineCellStyle);
      _putText(sheet, totalActR, colShift, '', styles.totalLabel);
      _putText(sheet, totalActR, colKind, 'Actual', styles.totalKindLabel);
      final totalActDFormula = List.generate(shifts.length, (i) {
        final shiftActExcel = blockStartExcel + (i * 2) + 1;
        return 'D$shiftActExcel';
      }).join('+');
      _putFormula(sheet, totalActR, colCum, totalActDFormula,
          styles.totalCumCell);
      for (var i = 0; i < days.length; i++) {
        final colLetter = _col(firstDayCol + i);
        final dayFormula = List.generate(shifts.length, (j) {
          final shiftActExcel = blockStartExcel + (j * 2) + 1;
          return '$colLetter$shiftActExcel';
        }).join('+');
        _putFormula(sheet, totalActR, firstDayCol + i, dayFormula,
            styles.totalCell);
      }
      r++;

      // Merge B column across Total pair too.
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: totalPlanR),
        CellIndex.indexByColumnRow(columnIndex: colShift, rowIndex: totalActR),
      );

      // ---- Per-shift Downtime rows --------------------------------------
      for (final shift in shifts) {
        final shiftHex = DplChartTokens.shiftColorByCode(shift.code);
        final row = _findRow(machineRows, machine.id, shift.id);

        final dtR = r;
        final dtExcel = dtR + 1;
        _putText(sheet, dtR, colMachine, '', machineCellStyle);
        _putText(
          sheet,
          dtR,
          colShift,
          '${shift.code}-shift Down Time in Minutes',
          styles.shiftLabel(shiftHex),
        );
        _putText(sheet, dtR, colKind, '', styles.shiftKindLabel(shiftHex));
        _putFormula(
          sheet,
          dtR,
          colCum,
          'SUM(${_col(firstDayCol)}$dtExcel:${_col(lastDayCol)}$dtExcel)',
          styles.shiftCumCell(shiftHex),
        );
        for (var i = 0; i < days.length; i++) {
          final cell = _cellOn(row, days[i]);
          _putInt(sheet, dtR, firstDayCol + i, cell?.downtimeMinutes ?? 0,
              styles.shiftCell(shiftHex));
        }
        r++;
      }

      // Merge column A (machine name) across the whole block. The label
      // text goes only on the first row; remaining cells in the merge are
      // already empty-but-styled so the band continues.
      final blockEndR = r - 1;
      _putText(
        sheet,
        blockStartR,
        colMachine,
        'Machine Name: ${machine.name}',
        machineCellStyle,
      );
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: colMachine, rowIndex: blockStartR),
        CellIndex.indexByColumnRow(columnIndex: colMachine, rowIndex: blockEndR),
      );
    }

    // ============================================================
    // Fill in the deferred Cumulative formulas (rows 2 & 3)
    // ============================================================
    // D2 = D{totalPlan1} + D{totalPlan2} + ... (sum across machines)
    // E2:lastDayCol@2 = same, per day column
    if (totalPlanRowsExcel.isNotEmpty) {
      final dCum = totalPlanRowsExcel.map((e) => 'D$e').join('+');
      _putFormula(sheet, cumPlanRowR, colCum, dCum, styles.headerData);
      for (var i = 0; i < days.length; i++) {
        final colLetter = _col(firstDayCol + i);
        final f = totalPlanRowsExcel.map((e) => '$colLetter$e').join('+');
        _putFormula(sheet, cumPlanRowR, firstDayCol + i, f, styles.headerData);
      }
    } else {
      _putInt(sheet, cumPlanRowR, colCum, 0, styles.headerData);
      for (var i = 0; i < days.length; i++) {
        _putInt(sheet, cumPlanRowR, firstDayCol + i, 0, styles.headerData);
      }
    }

    if (totalActualRowsExcel.isNotEmpty) {
      final dCum = totalActualRowsExcel.map((e) => 'D$e').join('+');
      _putFormula(sheet, cumActualRowR, colCum, dCum, styles.headerData);
      // B{cumActual} = IFERROR(D{cumActual}/D{cumPlan}, 0)   — achievement %
      final achFormula =
          'IFERROR(D${cumActualRowR + 1}/D${cumPlanRowR + 1},0)';
      _putFormula(sheet, cumActualRowR, colShift, achFormula,
          styles.headerHighlightPct);
      for (var i = 0; i < days.length; i++) {
        final colLetter = _col(firstDayCol + i);
        final f = totalActualRowsExcel.map((e) => '$colLetter$e').join('+');
        _putFormula(sheet, cumActualRowR, firstDayCol + i, f, styles.headerData);
      }
    } else {
      _putInt(sheet, cumActualRowR, colCum, 0, styles.headerData);
      _putText(sheet, cumActualRowR, colShift, '—', styles.headerHighlight);
      for (var i = 0; i < days.length; i++) {
        _putInt(sheet, cumActualRowR, firstDayCol + i, 0, styles.headerData);
      }
    }

    // Blank spacer row before the KPI block
    r++;

    // ============================================================
    // Bottom block — breakdown hours, headcount, lost MH, work MH
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
      // First pass: if there is *any* manpower entry for this exact
      // (date, shift) — including an explicit headcount of 0 — honour it
      // verbatim. Sum across machine_id variants so per-machine and
      // shift-wide rows both count.
      var sameDaySum = 0;
      var sameDayFound = false;
      for (final m in chart.manpower) {
        if (m.shiftId != shiftId) continue;
        if (_sameDay(m.date, date)) {
          sameDaySum += m.headcount;
          sameDayFound = true;
        }
      }
      if (sameDayFound) return sameDaySum;

      // Carry-forward: if the manager only entered headcount on the
      // first few days of the range, reuse the most recent prior day's
      // value for this shift so the rest of the month doesn't sit at
      // zero. This is intentional — DPL headcounts rarely change day
      // to day, so propagating the latest entry forward matches what
      // the floor manager actually wants on the printed chart.
      DateTime? bestDate;
      for (final m in chart.manpower) {
        if (m.shiftId != shiftId) continue;
        if (m.date.isAfter(date)) continue;
        if (bestDate == null || m.date.isAfter(bestDate)) {
          bestDate = m.date;
        }
      }
      if (bestDate == null) return 0;

      var fallback = 0;
      for (final m in chart.manpower) {
        if (m.shiftId != shiftId) continue;
        if (_sameDay(m.date, bestDate)) {
          fallback += m.headcount;
        }
      }
      return fallback;
    }

    void writeKpiCumRow(int rowR) {
      // Generic D = SUM(E:H) cum formula for KPI rows.
      final excelRow = rowR + 1;
      _putFormula(
        sheet,
        rowR,
        colCum,
        'SUM(${_col(firstDayCol)}$excelRow:${_col(lastDayCol)}$excelRow)',
        styles.kpiCumDecimalCell,
      );
    }

    for (final shift in shifts) {
      final shiftHex = DplChartTokens.shiftColorByCode(shift.code);
      final shiftLabel = '${shift.code}-shift';

      // Breakdown hours
      _putText(sheet, r, colMachine, 'Breakdown Hours',
          styles.shiftKpiLabel(shiftHex));
      _putText(sheet, r, colShift, shiftLabel,
          styles.shiftKpiLabel(shiftHex));
      _putText(sheet, r, colKind, '', styles.shiftKpiLabel(shiftHex));
      writeKpiCumRow(r);
      for (var i = 0; i < days.length; i++) {
        _putDouble(
          sheet,
          r,
          firstDayCol + i,
          _round1(breakdownHoursFor(days[i], shift.id)),
          styles.shiftKpiDecimalCell(shiftHex),
        );
      }
      r++;

      // No. of Manpower
      _putText(sheet, r, colMachine, 'No. of Manpower',
          styles.shiftKpiLabel(shiftHex));
      _putText(sheet, r, colShift, shiftLabel,
          styles.shiftKpiLabel(shiftHex));
      _putText(sheet, r, colKind, '', styles.shiftKpiLabel(shiftHex));
      writeKpiCumRow(r);
      for (var i = 0; i < days.length; i++) {
        _putInt(
          sheet,
          r,
          firstDayCol + i,
          headcountFor(days[i], shift.id),
          styles.shiftKpiIntCell(shiftHex),
        );
      }
      r++;

      // Per-machine lost work-man-hours for this shift
      for (var mIdx = 0; mIdx < machines.length; mIdx++) {
        final machine = machines[mIdx];
        _putText(
          sheet,
          r,
          colMachine,
          '${machine.name} lost Work Man Hours',
          styles.shiftKpiLabel(shiftHex),
        );
        _putText(sheet, r, colShift, shiftLabel,
            styles.shiftKpiLabel(shiftHex));
        _putText(sheet, r, colKind, '', styles.shiftKpiLabel(shiftHex));
        writeKpiCumRow(r);
        for (var i = 0; i < days.length; i++) {
          final br = breakdownHoursForMachine(days[i], shift.id, machine.id);
          final hc = headcountFor(days[i], shift.id);
          _putDouble(
            sheet,
            r,
            firstDayCol + i,
            _round1(br * hc),
            styles.shiftKpiDecimalCell(shiftHex),
          );
        }
        r++;
      }
    }

    // Total Lost Work Man Hours per day
    _putText(sheet, r, colMachine,
        'Total Lost Work Man Hours Due to Breakdown', styles.totalLabel);
    _putText(sheet, r, colShift, '', styles.totalLabel);
    _putText(sheet, r, colKind, '', styles.totalLabel);
    writeKpiCumRow(r);
    for (var i = 0; i < days.length; i++) {
      var totalLost = 0.0;
      for (final shift in shifts) {
        final hc = headcountFor(days[i], shift.id);
        for (final machine in machines) {
          final br = breakdownHoursForMachine(days[i], shift.id, machine.id);
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

    // Per-shift / per-machine Work Man Hours = (headcount ÷ machine_count) × 8
    for (final shift in shifts) {
      final shiftHex = DplChartTokens.shiftColorByCode(shift.code);
      for (var mIdx = 0; mIdx < machines.length; mIdx++) {
        final machine = machines[mIdx];

        _putText(
          sheet,
          r,
          colMachine,
          '${machine.name} Work Man Hours',
          styles.shiftKpiLabel(shiftHex),
        );
        _putText(sheet, r, colShift, '${shift.code}-shift',
            styles.shiftKpiLabel(shiftHex));
        _putText(sheet, r, colKind, '', styles.shiftKpiLabel(shiftHex));
        writeKpiCumRow(r);
        for (var i = 0; i < days.length; i++) {
          final hc = headcountFor(days[i], shift.id);
          final share = machines.isEmpty ? hc : (hc / machines.length);
          _putDouble(
            sheet,
            r,
            firstDayCol + i,
            _round1(share * 8),
            styles.shiftKpiDecimalCell(shiftHex),
          );
        }
        r++;
      }
    }

    // Total Work Man Hours per day
    _putText(sheet, r, colMachine, 'Total Work Man Hours', styles.totalLabel);
    _putText(sheet, r, colShift, '', styles.totalLabel);
    _putText(sheet, r, colKind, '', styles.totalLabel);
    writeKpiCumRow(r);
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
    _putText(sheet, r, colMachine, '% of lost man Hours', styles.headerLabel);
    _putText(sheet, r, colShift, '', styles.headerLabel);
    _putText(sheet, r, colKind, '', styles.headerLabel);
    writeKpiCumRow(r);
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
    // Column widths
    // ============================================================
    sheet.setColumnWidth(colMachine, 31);
    sheet.setColumnWidth(colShift, 26);
    sheet.setColumnWidth(colKind, 8);
    sheet.setColumnWidth(colCum, 12);
    for (var i = 0; i < days.length; i++) {
      // Wide enough to fit a "dd-mmm" header like "01-Jun".
      sheet.setColumnWidth(firstDayCol + i, 9);
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Failed to encode Excel file.');
    }

    // The `excel` package doesn't expose freeze-pane configuration, so we
    // patch the worksheet XML directly: freeze 4 left columns (A–D) and
    // 7 top rows (title + particulars header + as-of snapshot +
    // cumulative + achievement + day-of-week + date headers).
    final patched = _injectFreezePane(
      Uint8List.fromList(encoded),
      xSplit: 4,
      ySplit: 7,
    );
    return patched;
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

  static void _putFormula(
    Sheet sheet,
    int row,
    int col,
    String formula,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = FormulaCellValue(formula);
    cell.cellStyle = style;
  }

  static void _putDate(
    Sheet sheet,
    int row,
    int col,
    DateTime value,
    CellStyle style,
  ) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    cell.value = DateCellValue.fromDateTime(value);
    cell.cellStyle = style;
  }

  static double _round1(double v) =>
      double.parse(v.toStringAsFixed(1));

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Convert a 0-indexed column number to its Excel letter (0 → A, 25 → Z,
  /// 26 → AA, ...). Sufficient for any practical day-of-month range.
  static String _col(int index) {
    var n = index;
    final out = StringBuffer();
    while (true) {
      final r = n % 26;
      out.write(String.fromCharCode(65 + r));
      n = (n ~/ 26) - 1;
      if (n < 0) break;
    }
    return out.toString().split('').reversed.join();
  }

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

  /// Post-processes the `excel` package's output to inject a freeze pane.
  /// The package emits a bare `<sheetView workbookViewId="0"/>` and provides
  /// no API to add a `<pane>` child, so we patch the XML directly.
  static Uint8List _injectFreezePane(
    Uint8List bytes, {
    required int xSplit,
    required int ySplit,
  }) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final patchedFiles = <ArchiveFile>[];

      for (final file in archive.files) {
        if (file.name.startsWith('xl/worksheets/sheet') &&
            file.name.endsWith('.xml')) {
          final raw = file.content;
          final xml = raw is List<int> ? utf8.decode(raw) : raw.toString();
          final patchedXml = _patchSheetViewXml(xml, xSplit, ySplit);
          final encoded = utf8.encode(patchedXml);
          patchedFiles.add(
            ArchiveFile(file.name, encoded.length, encoded),
          );
        } else {
          patchedFiles.add(file);
        }
      }

      final newArchive = Archive();
      for (final f in patchedFiles) {
        newArchive.addFile(f);
      }
      final reencoded = ZipEncoder().encode(newArchive);
      if (reencoded == null) return bytes;
      return Uint8List.fromList(reencoded);
    } catch (_) {
      // If anything goes wrong while patching freeze panes, fall back to
      // the original bytes — better to ship a file without freezes than a
      // corrupt one.
      return bytes;
    }
  }

  static String _patchSheetViewXml(String xml, int xSplit, int ySplit) {
    final topLeftCol = _col(xSplit);
    final topLeftRow = ySplit + 1;
    final paneXml =
        '<pane xSplit="$xSplit" ySplit="$ySplit" topLeftCell="$topLeftCol$topLeftRow" activePane="bottomRight" state="frozen"/>';

    // Form A: self-closing <sheetView .../>
    final selfClose = RegExp(r'<sheetView\b[^/>]*\/>');
    final mA = selfClose.firstMatch(xml);
    if (mA != null) {
      final tag = mA.group(0)!;
      final opened = tag.replaceFirst('/>', '>');
      final replacement = '$opened$paneXml</sheetView>';
      return xml.replaceFirst(tag, replacement);
    }

    // Form B: <sheetView ...>...</sheetView>
    final openTag = RegExp(r'<sheetView\b[^>]*>');
    final mB = openTag.firstMatch(xml);
    if (mB != null) {
      return xml.replaceFirst(mB.group(0)!, '${mB.group(0)!}$paneXml');
    }

    // Form C: no sheetView at all — inject sheetViews block right after
    // the worksheet open tag.
    final wsOpen = RegExp(r'<worksheet\b[^>]*>');
    final mC = wsOpen.firstMatch(xml);
    if (mC != null) {
      final injected =
          '<sheetViews><sheetView workbookViewId="0">$paneXml</sheetView></sheetViews>';
      return xml.replaceFirst(mC.group(0)!, '${mC.group(0)!}$injected');
    }

    return xml;
  }
}

/// All pre-built [CellStyle] objects, grouped here so the
/// builder above stays focused on layout, not formatting.
class _Styles {
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

  /// Date-row variant — displays a real date serial as `dd-mmm` (e.g.
  /// "01-Jun") instead of a bare day-of-month integer. Lets the snapshot
  /// row's `MATCH(TODAY()-1, ...)` lookup work against actual dates.
  late final CellStyle dateBandDateCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgDateBand),
    bold: true,
    numberFormat: NumFormat.custom(formatCode: 'dd-mmm'),
  );

  late final CellStyle totalLabel = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    bold: true,
    h: HorizontalAlign.Left,
    wrap: TextWrapping.WrapText,
  );

  late final CellStyle totalKindLabel = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    fg: ExcelColor.fromHexString(DplChartTokens.fgEmphasisLabel),
    bold: true,
  );

  late final CellStyle totalCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    bold: true,
  );

  late final CellStyle totalCumCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    bold: true,
  );

  late final CellStyle totalDecimalCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgTotalBand),
    bold: true,
    numberFormat: NumFormat.custom(formatCode: '0.0'),
  );

  // Per-shift styles — cached so each hex builds its CellStyle once.
  final Map<String, CellStyle> _shiftCellCache = {};
  final Map<String, CellStyle> _shiftLabelCache = {};
  final Map<String, CellStyle> _shiftKindLabelCache = {};
  final Map<String, CellStyle> _shiftCumCache = {};
  final Map<String, CellStyle> _shiftKpiLabelCache = {};
  final Map<String, CellStyle> _shiftKpiIntCache = {};
  final Map<String, CellStyle> _shiftKpiDecimalCache = {};
  final Map<String, CellStyle> _machineNameCache = {};

  CellStyle shiftCell(String hex) => _shiftCellCache.putIfAbsent(
        hex,
        () => _bordered(bg: ExcelColor.fromHexString(hex)),
      );

  CellStyle shiftLabel(String hex) => _shiftLabelCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          bold: true,
          h: HorizontalAlign.Left,
          wrap: TextWrapping.WrapText,
        ),
      );

  CellStyle shiftKindLabel(String hex) => _shiftKindLabelCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          fg: ExcelColor.fromHexString(DplChartTokens.fgEmphasisLabel),
          bold: true,
        ),
      );

  CellStyle shiftCumCell(String hex) => _shiftCumCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          bold: true,
        ),
      );

  CellStyle shiftKpiLabel(String hex) => _shiftKpiLabelCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          bold: true,
          h: HorizontalAlign.Left,
          wrap: TextWrapping.WrapText,
        ),
      );

  CellStyle shiftKpiIntCell(String hex) => _shiftKpiIntCache.putIfAbsent(
        hex,
        () => _bordered(bg: ExcelColor.fromHexString(hex)),
      );

  CellStyle shiftKpiDecimalCell(String hex) =>
      _shiftKpiDecimalCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          numberFormat: NumFormat.custom(formatCode: '0.0'),
        ),
      );

  late final CellStyle kpiCumDecimalCell = _bordered(
    bg: ExcelColor.fromHexString(DplChartTokens.bgKpiBand),
    bold: true,
    numberFormat: NumFormat.custom(formatCode: '0.0'),
  );

  CellStyle machineNameCell(String hex) => _machineNameCache.putIfAbsent(
        hex,
        () => _bordered(
          bg: ExcelColor.fromHexString(hex),
          bold: true,
          h: HorizontalAlign.Left,
          wrap: TextWrapping.WrapText,
        ),
      );
}
