import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../models/dpl_monthly_chart.dart';

/// Client-side Excel exporter that reproduces the company's
/// "Daily Production Loading Chart" layout from a live
/// [DplMonthlyChart] payload (no server-side template needed).
///
/// Layout (rows, top to bottom):
///   1. Cumulative summary header   — "Cumulative Till Date", running totals
///   2. Achievement summary header  — "Achievement", running %, downtime
///   3. Date headers                — day numbers + weekday short codes
///   4. Per-machine block (×N machines):
///        - Shift A: Plan row + Actual row
///        - Shift B: Plan row + Actual row
///        - Shift C: Plan row + Actual row  (only if backend has Shift C)
///        - Total:   Plan row + Actual row  (sums all shifts per day)
///        - One "`<Shift>` Down Time in Minutes" row per shift
///   5. Bottom block:
///        - Per-shift / per-machine breakdown hours
///        - Per-shift manpower headcount
///        - Per-shift / per-machine lost work-hours (= breakdown × headcount)
///        - Totals row + % of lost man hours
class DplChartExcelExporter {
  const DplChartExcelExporter._();

  static Uint8List build(DplMonthlyChart chart) {
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

    // ============================================================
    // Row 1 — Cumulative Till Date  + per-day cumulative Plan
    // ============================================================
    final cumPlan = c.planQty;
    final cumActual = c.actualQty;
    final achievement = (c.achievementPct * 100);

    // Build per-day cumulative running totals so columns line up like
    // the company spreadsheet's top band.
    final dailyTotalPlan = <int>[];
    final dailyTotalActual = <int>[];
    for (final d in days) {
      var p = 0;
      var a = 0;
      for (final row in chart.rows) {
        for (final cell in row.daily) {
          if (cell.date.year == d.year &&
              cell.date.month == d.month &&
              cell.date.day == d.day) {
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

    sheet.appendRow([
      TextCellValue('Cumulative Till Date'),
      TextCellValue('$cumActual / $cumPlan'),
      TextCellValue('Cum. Plan'),
      ...cumPlanByDay.map((v) => IntCellValue(v)),
    ]);

    sheet.appendRow([
      TextCellValue('Achievement'),
      TextCellValue('${achievement.toStringAsFixed(1)}%'),
      TextCellValue('Cum. Actual'),
      ...cumActualByDay.map((v) => IntCellValue(v)),
    ]);

    // ============================================================
    // Row 3 — Day-of-week header   (Day, Date)
    // ============================================================
    final dowFmt = DateFormat('EEE');
    sheet.appendRow([
      TextCellValue(''),
      TextCellValue('Day'),
      TextCellValue('Date'),
      ...days.map((d) => TextCellValue(dowFmt.format(d))),
    ]);

    final dateFmt = DateFormat('d-MMM');
    sheet.appendRow([
      TextCellValue('Machine'),
      TextCellValue('Shift'),
      TextCellValue(''),
      ...days.map((d) => TextCellValue(dateFmt.format(d))),
    ]);

    // ============================================================
    // Per-machine sections
    // ============================================================
    for (final machine in machines) {
      final machineRows = chart.rows
          .where((r) => r.machineId == machine.id)
          .toList();

      // Per-day Plan / Actual per shift
      for (final shift in shifts) {
        final row = machineRows.firstWhere(
          (r) => r.shiftId == shift.id,
          orElse: () => DplChartRow(
            machineId: machine.id,
            shiftId: shift.id,
            daily: const [],
            totals: DplChartTotals.empty(),
          ),
        );

        final planCells = <int>[];
        final actualCells = <int>[];
        for (final d in days) {
          final cell = row.daily.cast<DplChartCell?>().firstWhere(
                (c) =>
                    c != null &&
                    c.date.year == d.year &&
                    c.date.month == d.month &&
                    c.date.day == d.day,
                orElse: () => null,
              );
          planCells.add(cell?.planQty ?? 0);
          actualCells.add(cell?.actualQty ?? 0);
        }

        // Plan row
        sheet.appendRow([
          TextCellValue('Machine Name: ${machine.name}'),
          TextCellValue('Shift ${shift.code}'),
          TextCellValue('Plan'),
          ...planCells.map((v) => IntCellValue(v)),
        ]);
        // Actual row
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(''),
          TextCellValue('Actual'),
          ...actualCells.map((v) => IntCellValue(v)),
        ]);
      }

      // Totals (sum across shifts) per day
      final totalPlanByDay = <int>[];
      final totalActualByDay = <int>[];
      for (final d in days) {
        var p = 0;
        var a = 0;
        for (final row in machineRows) {
          for (final cell in row.daily) {
            if (cell.date.year == d.year &&
                cell.date.month == d.month &&
                cell.date.day == d.day) {
              p += cell.planQty;
              a += cell.actualQty;
            }
          }
        }
        totalPlanByDay.add(p);
        totalActualByDay.add(a);
      }
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue('Total'),
        TextCellValue('Plan'),
        ...totalPlanByDay.map((v) => IntCellValue(v)),
      ]);
      sheet.appendRow([
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue('Actual'),
        ...totalActualByDay.map((v) => IntCellValue(v)),
      ]);

      // Per-shift downtime rows for this machine
      for (final shift in shifts) {
        final row = machineRows.firstWhere(
          (r) => r.shiftId == shift.id,
          orElse: () => DplChartRow(
            machineId: machine.id,
            shiftId: shift.id,
            daily: const [],
            totals: DplChartTotals.empty(),
          ),
        );
        final dtByDay = <int>[];
        for (final d in days) {
          final cell = row.daily.cast<DplChartCell?>().firstWhere(
                (c) =>
                    c != null &&
                    c.date.year == d.year &&
                    c.date.month == d.month &&
                    c.date.day == d.day,
                orElse: () => null,
              );
          dtByDay.add(cell?.downtimeMinutes ?? 0);
        }
        sheet.appendRow([
          TextCellValue(''),
          TextCellValue(
              '${shift.code}-shift Down Time in Minutes'),
          TextCellValue(''),
          ...dtByDay.map((v) => IntCellValue(v)),
        ]);
      }

      // Spacer row between machines
      sheet.appendRow([TextCellValue('')]);
    }

    // ============================================================
    // Bottom block — per-shift breakdown hours, headcount, lost MH
    // ============================================================

    // Helper: total breakdown hours for (date, shift) summed across machines
    double breakdownHoursFor(DateTime date, int shiftId) {
      var sum = 0.0;
      for (final b in chart.breakdownHours) {
        if (b.shiftId != shiftId) continue;
        if (b.date.year != date.year ||
            b.date.month != date.month ||
            b.date.day != date.day) {
          continue;
        }
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
        if (b.date.year != date.year ||
            b.date.month != date.month ||
            b.date.day != date.day) {
          continue;
        }
        sum += b.byMachine[machineId] ?? 0;
      }
      return sum;
    }

    int headcountFor(DateTime date, int shiftId) {
      // Shift-wide headcount = sum of all manpower rows for that date/shift
      // (covers either shift-wide entries OR per-machine entries).
      var sum = 0;
      for (final m in chart.manpower) {
        if (m.shiftId != shiftId) continue;
        if (m.date.year != date.year ||
            m.date.month != date.month ||
            m.date.day != date.day) {
          continue;
        }
        sum += m.headcount;
      }
      return sum;
    }

    // Per-shift, per-machine sections
    for (final shift in shifts) {
      final shiftLabel = '${shift.code}-shift';

      // Breakdown hours (total)
      sheet.appendRow([
        TextCellValue('Breakdown Hours'),
        TextCellValue(shiftLabel),
        TextCellValue(''),
        ...days.map(
          (d) => DoubleCellValue(
            double.parse(
              breakdownHoursFor(d, shift.id).toStringAsFixed(1),
            ),
          ),
        ),
      ]);

      // No. of Manpower
      sheet.appendRow([
        TextCellValue('No. of Manpower'),
        TextCellValue(shiftLabel),
        TextCellValue(''),
        ...days.map((d) => IntCellValue(headcountFor(d, shift.id))),
      ]);

      // Per-machine lost work-man-hours = breakdown hours × headcount
      for (final machine in machines) {
        sheet.appendRow([
          TextCellValue('${machine.name} lost Work Man Hours'),
          TextCellValue(shiftLabel),
          TextCellValue(''),
          ...days.map((d) {
            final br = breakdownHoursForMachine(d, shift.id, machine.id);
            final hc = headcountFor(d, shift.id);
            return DoubleCellValue(
              double.parse((br * hc).toStringAsFixed(1)),
            );
          }),
        ]);
      }

      // Spacer
      sheet.appendRow([TextCellValue('')]);
    }

    // Total lost work-man-hours per day (sum across shifts and machines)
    sheet.appendRow([
      TextCellValue('Total Lost Work Man Hours Due to Breakdown'),
      TextCellValue(''),
      TextCellValue(''),
      ...days.map((d) {
        var totalLost = 0.0;
        for (final shift in shifts) {
          final hc = headcountFor(d, shift.id);
          for (final machine in machines) {
            final br = breakdownHoursForMachine(d, shift.id, machine.id);
            totalLost += br * hc;
          }
        }
        return DoubleCellValue(
          double.parse(totalLost.toStringAsFixed(1)),
        );
      }),
    ]);

    // Per-shift / per-machine Work Man Hours = headcount × 8h
    // (matches the backend's `total_man_hours = Σ(headcount × 8h)` rule)
    for (final shift in shifts) {
      for (final machine in machines) {
        sheet.appendRow([
          TextCellValue('${machine.name} Work Man Hours'),
          TextCellValue('${shift.code}-shift'),
          TextCellValue(''),
          ...days.map((d) {
            final hc = headcountFor(d, shift.id);
            // Assume each machine gets equal share of shift's manpower.
            // (Backend can refine this; matches the simple approximation
            // the spreadsheet uses.)
            final share =
                machines.isEmpty ? hc : (hc / machines.length);
            return DoubleCellValue(
              double.parse((share * 8).toStringAsFixed(1)),
            );
          }),
        ]);
      }
    }

    // Total Work Man Hours per day
    sheet.appendRow([
      TextCellValue('Total Work Man Hours'),
      TextCellValue(''),
      TextCellValue(''),
      ...days.map((d) {
        var totalMh = 0.0;
        for (final shift in shifts) {
          totalMh += headcountFor(d, shift.id) * 8;
        }
        return DoubleCellValue(
          double.parse(totalMh.toStringAsFixed(1)),
        );
      }),
    ]);

    // % of lost man hours per day
    sheet.appendRow([
      TextCellValue('% of lost man Hours'),
      TextCellValue(''),
      TextCellValue(''),
      ...days.map((d) {
        var totalMh = 0.0;
        var totalLost = 0.0;
        for (final shift in shifts) {
          final hc = headcountFor(d, shift.id);
          totalMh += hc * 8;
          for (final machine in machines) {
            final br =
                breakdownHoursForMachine(d, shift.id, machine.id);
            totalLost += br * hc;
          }
        }
        if (totalMh <= 0) return TextCellValue('—');
        final pct = (totalLost / totalMh) * 100;
        return TextCellValue('${pct.toStringAsFixed(1)}%');
      }),
    ]);

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Failed to encode Excel file.');
    }
    return Uint8List.fromList(encoded);
  }
}
