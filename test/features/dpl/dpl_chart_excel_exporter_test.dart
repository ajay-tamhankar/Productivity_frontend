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
  });
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
