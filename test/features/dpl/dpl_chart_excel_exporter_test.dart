import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/dpl/manager/services/dpl_chart_excel_exporter.dart';
import 'package:productivity_tracker/features/dpl/models/dpl_machine.dart';
import 'package:productivity_tracker/features/dpl/models/dpl_manpower_log.dart';
import 'package:productivity_tracker/features/dpl/models/dpl_monthly_chart.dart';
import 'package:productivity_tracker/features/dpl/models/dpl_shift.dart';

void main() {
  group('DplChartExcelExporter', () {
    test('throws StateError when the range has zero days', () {
      final empty = DplMonthlyChart.empty(
        DateTime(2026, 5, 1),
        DateTime(2026, 5, 1),
      );
      expect(() => DplChartExcelExporter.build(empty), throwsStateError);
    });

    test('produces a non-empty .xlsx for a 3-machine, 2-shift, 5-day month',
        () {
      final chart = _buildSyntheticChart(days: 5, machines: 3, shifts: 2);
      final bytes = DplChartExcelExporter.build(chart);

      // .xlsx files are zip archives → must start with "PK\x03\x04".
      expect(bytes.length, greaterThan(2000),
          reason: 'styled .xlsx should be at least a few KB');
      expect(bytes[0], 0x50, reason: 'first byte of PK header');
      expect(bytes[1], 0x4B);
      expect(bytes[2], 0x03);
      expect(bytes[3], 0x04);
    });

    test('handles a single machine + single shift without crashing', () {
      final chart = _buildSyntheticChart(days: 3, machines: 1, shifts: 1);
      final bytes = DplChartExcelExporter.build(chart);
      expect(bytes.length, greaterThan(2000));
    });

    test('handles more machines than predefined band colors '
        '(modulo wraparound)', () {
      final chart = _buildSyntheticChart(days: 2, machines: 8, shifts: 2);
      expect(() => DplChartExcelExporter.build(chart), returnsNormally);
    });

    test('injects a freeze pane (4 cols × 7 rows) into the worksheet XML', () {
      final chart = _buildSyntheticChart(days: 4, machines: 2, shifts: 3);
      final bytes = DplChartExcelExporter.build(chart);
      final sheetXml = _readSheetXml(bytes);

      // Freeze pane must reference column E (= xSplit=4) and row 8 (= ySplit=7).
      // 7 frozen header rows: title + particulars + as-of snapshot +
      // cumulative + achievement + day-of-week + date numbers.
      expect(sheetXml, contains('xSplit="4"'));
      expect(sheetXml, contains('ySplit="7"'));
      expect(sheetXml, contains('state="frozen"'));
      expect(sheetXml, contains('topLeftCell="E8"'));
    });

    test('emits SUM and shift-aggregate formulas in column D', () {
      final chart = _buildSyntheticChart(days: 3, machines: 1, shifts: 3);
      final bytes = DplChartExcelExporter.build(chart);
      final sheetXml = _readSheetXml(bytes);

      // Per-shift Plan rows: D = SUM(E{r}:G{r}). Row 8 is first shift Plan
      // (header occupies rows 1–7).
      expect(sheetXml, contains('SUM(E8:G8)'));
      // Per-machine Total Plan row aggregates each shift's D cell. With one
      // machine + 3 shifts the Total Plan row is Excel row 14 and its D cell
      // formula is D8+D10+D12 (the per-shift Plan rows at offsets 0/2/4).
      expect(sheetXml, contains('D8+D10+D12'));
    });

    test('merges machine name column across the whole block', () {
      final chart = _buildSyntheticChart(days: 2, machines: 2, shifts: 3);
      final bytes = DplChartExcelExporter.build(chart);
      final sheetXml = _readSheetXml(bytes);

      // First machine block spans 11 rows starting at Excel row 8 (header
      // occupies rows 1–7). So A8:A18 must be in the merges.
      expect(sheetXml, contains('A8:A18'));
      // Second machine block follows immediately: A19:A29.
      expect(sheetXml, contains('A19:A29'));
    });

    test('writes the "Particulars / Actual-Plan" as-of snapshot block', () {
      final chart = _buildSyntheticChart(days: 3, machines: 2, shifts: 3);
      final bytes = DplChartExcelExporter.build(chart);
      final sharedStrings = _readArchiveFile(bytes, 'xl/sharedStrings.xml');
      final sheetXml = _readSheetXml(bytes);

      // Header labels live in shared strings.
      expect(sharedStrings, contains('Particulars'));
      expect(sharedStrings, contains('Actual / Plan'));

      // A3 must be the live `TEXT(TODAY()-1,"d-mmm")` formula so the date
      // stays in sync with when the spreadsheet is opened and renders as a
      // left-aligned string ("3-Jun") rather than a date serial.
      expect(sheetXml, contains('TEXT(TODAY()-1'));

      // B3 must be a lookup formula — IFERROR + INDEX/MATCH against the
      // date row (row 7) and the per-day cumulative rows (4 & 5). The
      // date row stores real date serials now, so the formula matches
      // TODAY()-1 directly (no DAY() extraction).
      expect(sheetXml, contains('MATCH(TODAY()-1'));
      expect(sheetXml, contains('INDEX(E5:G5'));
      expect(sheetXml, contains('INDEX(E4:G4'));

      // B4 (Cumulative Till Date) must also be a formula concatenating
      // the cumulative actual and plan from D5 / D4. Excel escapes `&`
      // inside `<f>` as `&amp;` when saving the workbook.
      expect(sheetXml, contains('D5&amp;" / "&amp;D4'));
    });

    test('carries headcount forward into days with no manpower entry', () {
      // Build a 5-day chart but only enter manpower on day 1
      // (shift A, headcount 5; shift B, headcount 4). Days 2–5 have no
      // entries, which is the realistic "manager entered manpower once"
      // case.
      final base = _buildSyntheticChart(days: 5, machines: 1, shifts: 2);
      final day1 = base.days.first;
      final sparseChart = DplMonthlyChart(
        from: base.from,
        to: base.to,
        days: base.days,
        shifts: base.shifts,
        machines: base.machines,
        rows: base.rows,
        breakdownHours: base.breakdownHours,
        cumulative: base.cumulative,
        manpower: [
          DplManpowerLog(id: 1, date: day1, shiftId: 1, headcount: 5),
          DplManpowerLog(id: 2, date: day1, shiftId: 2, headcount: 4),
        ],
      );

      final bytes = DplChartExcelExporter.build(sparseChart);
      final sheetXml = _readSheetXml(bytes);

      // The two "No. of Manpower" rows write headcount via _putInt, so the
      // 5 and 4 values appear verbatim in <v> tags. With carry-forward,
      // each value must appear at least 5 times (once per day in the
      // range), not just once on day 1.
      //
      // Counting matches keeps the test resilient against any other
      // incidental `<v>5</v>` / `<v>4</v>` in the document.
      final count5 = '<v>5</v>'.allMatches(sheetXml).length;
      final count4 = '<v>4</v>'.allMatches(sheetXml).length;
      expect(count5, greaterThanOrEqualTo(5),
          reason: 'shift-A headcount 5 should fill all 5 days');
      expect(count4, greaterThanOrEqualTo(5),
          reason: 'shift-B headcount 4 should fill all 5 days');
    });

    test('does not embed the deprecated red label color (FFFF0000)', () {
      final chart = _buildSyntheticChart(days: 2, machines: 1, shifts: 3);
      final bytes = DplChartExcelExporter.build(chart);
      final stylesXml = _readArchiveFile(bytes, 'xl/styles.xml');

      // Match Excel's rgb attribute exactly to avoid false positives from
      // theme color indexes that happen to contain FFFF0000 as a substring.
      expect(stylesXml, isNot(contains('rgb="FFFF0000"')));
    });
  });
}

String _readSheetXml(List<int> xlsxBytes) {
  return _readArchiveFile(xlsxBytes, 'xl/worksheets/sheet1.xml');
}

String _readArchiveFile(List<int> xlsxBytes, String path) {
  final archive = ZipDecoder().decodeBytes(xlsxBytes);
  for (final f in archive.files) {
    if (f.name == path) {
      final c = f.content;
      if (c is List<int>) return utf8.decode(c);
      return c.toString();
    }
  }
  throw StateError('Missing $path in produced .xlsx');
}

/// Minimal payload that mirrors the shape of `GET /manager/reports/dpl-chart`
/// — enough to exercise every branch of the exporter without touching
/// the backend.
DplMonthlyChart _buildSyntheticChart({
  required int days,
  required int machines,
  required int shifts,
}) {
  final from = DateTime(2026, 5, 1);
  final dayList = List<DateTime>.generate(
    days,
    (i) => DateTime(from.year, from.month, from.day + i),
  );

  final shiftList = List<DplShift>.generate(
    shifts,
    (i) => DplShift(
      id: i + 1,
      code: String.fromCharCode(0x41 + i), // 'A', 'B', 'C', ...
      name: 'Shift ${String.fromCharCode(0x41 + i)}',
      startTime: '08:00',
      endTime: '16:00',
    ),
  );

  final machineList = List<DplMachine>.generate(
    machines,
    (i) => DplMachine(
      id: i + 1,
      code: 'M${i + 1}',
      name: 'Machine ${i + 1}',
    ),
  );

  final rows = <DplChartRow>[];
  for (final m in machineList) {
    for (final s in shiftList) {
      final daily = <DplChartCell>[];
      var plan = 0;
      var actual = 0;
      for (final d in dayList) {
        final p = 100 + d.day;
        final a = 80 + d.day;
        daily.add(DplChartCell(
          date: d,
          planQty: p,
          actualQty: a,
          downtimeMinutes: 10 * d.day,
        ));
        plan += p;
        actual += a;
      }
      rows.add(DplChartRow(
        machineId: m.id,
        shiftId: s.id,
        daily: daily,
        totals: DplChartTotals(
          planQty: plan,
          actualQty: actual,
          downtimeMinutes: 0,
        ),
      ));
    }
  }

  final manpower = <DplManpowerLog>[
    for (final d in dayList)
      for (final s in shiftList)
        DplManpowerLog(
          id: d.day * 10 + s.id,
          date: d,
          shiftId: s.id,
          headcount: 4,
        ),
  ];

  return DplMonthlyChart(
    from: dayList.first,
    to: dayList.last,
    days: dayList,
    shifts: shiftList,
    machines: machineList,
    rows: rows,
    manpower: manpower,
    breakdownHours: const [],
    cumulative: const DplChartCumulative(
      planQty: 0,
      actualQty: 0,
      achievementPct: 0,
      totalDowntimeMinutes: 0,
      totalManHours: 0,
      totalLostManHours: 0,
      lostPct: 0,
    ),
  );
}
