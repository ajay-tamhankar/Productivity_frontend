import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/dpl/core/dpl_api_service.dart';
import 'package:productivity_tracker/features/dpl/manager/services/dpl_chart_excel_exporter.dart';

/// End-to-end check for the Monthly DPL Chart pipeline.
///
/// Mocks `GET /manager/reports/dpl-chart` to return the exact envelope shape
/// the backend ships (`{ success: true, data: { ...payload } }`) for the
/// confirmed live May-2026 dataset (6 manpower rows, totalManHours: 184).
/// Asserts:
///   1. `_send` unwraps the envelope and forwards only the payload to
///      `DplMonthlyChart.fromJson`.
///   2. `manpower`, `breakdown_hours`, and `cumulative` parse correctly,
///      including the case where `machine_id` is omitted (shift-wide row).
///   3. The Excel exporter emits the headcount numbers into the worksheet
///      XML — proving the data flows all the way to "No. of Manpower"
///      cells.
void main() {
  group('DplApiService.reportDplChart (envelope + chart export)', () {
    test('parses a live envelope and feeds non-zero data into the exporter',
        () async {
      // Backend envelope, mirroring the May-2026 sample the user cited.
      final responseEnvelope = {
        'success': true,
        'data': _liveMay2026Payload(),
      };

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: responseEnvelope,
            ));
          },
        ),
      );

      final api = DplApiService(dio);
      final result = await api.reportDplChart(
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 5, 2),
      );

      expect(result.isError, isFalse, reason: result.error);
      final chart = result.data!;

      // (1) Envelope unwrap — top-level fields are populated.
      expect(chart.days.length, 2);
      expect(chart.shifts.length, 3);
      expect(chart.machines.length, 1);

      // (2) manpower parses: 6 entries, mix of shift-wide and per-machine.
      expect(chart.manpower.length, 6);
      final shiftWide = chart.manpower.where((m) => m.machineId == null);
      final perMachine = chart.manpower.where((m) => m.machineId != null);
      expect(shiftWide.length, 4);
      expect(perMachine.length, 2);
      expect(chart.manpower.first.headcount, greaterThan(0));

      // breakdown_hours parses including `by_machine`.
      expect(chart.breakdownHours.length, 1);
      expect(chart.breakdownHours.first.byMachine[1], 1.4);

      // cumulative aggregates parse.
      expect(chart.cumulative.totalManHours, 184);
      expect(chart.cumulative.totalLostManHours, closeTo(11.72, 0.01));
      expect(chart.cumulative.lostPct, closeTo(0.0637, 0.0001));

      // (3) Excel export carries the headcount values through. Day 1
      // shift-A headcount = 4 — the "No. of Manpower" row's day-1 cell
      // must contain that value.
      final bytes = DplChartExcelExporter.build(chart);
      final sheetXml = _readSheetXml(bytes);

      // Headcount 4 appears verbatim as <v>4</v> in the "No. of Manpower"
      // row's day cells (rendered via _putInt, not as a formula).
      expect(sheetXml, contains('<v>4</v>'));
      // The breakdown-hours row value (1.4) and lost-WMH derivation
      // (1.4 × 4 = 5.6) should also be in the sheet.
      expect(sheetXml, contains('1.4'));
      expect(sheetXml, contains('5.6'));
    });

    test('treats missing manpower as zero — no crash, em-dash for % row',
        () async {
      final payload = _liveMay2026Payload();
      // Wipe manpower to simulate a date range with no entries.
      payload['manpower'] = const <dynamic>[];

      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': payload},
            ));
          },
        ),
      );

      final api = DplApiService(dio);
      final result = await api.reportDplChart(
        from: DateTime(2026, 5, 1),
        to: DateTime(2026, 5, 2),
      );

      expect(result.isError, isFalse);
      final chart = result.data!;
      expect(chart.manpower, isEmpty);

      // Exporter must still produce a valid file (zip header) and surface
      // the em-dash in the "% of lost man Hours" row instead of dividing
      // by zero. Excel keeps string values in the shared-strings table,
      // not inline in the sheet XML, so look there.
      final bytes = DplChartExcelExporter.build(chart);
      expect(bytes.length, greaterThan(2000));
      final sharedStrings = _readArchiveFile(bytes, 'xl/sharedStrings.xml');
      expect(sharedStrings, contains('—'));
    });
  });
}

String _readArchiveFile(List<int> xlsxBytes, String path) {
  final archive = ZipDecoder().decodeBytes(xlsxBytes);
  for (final f in archive.files) {
    if (f.name == path) {
      final c = f.content;
      return c is List<int> ? utf8.decode(c) : c.toString();
    }
  }
  throw StateError('Missing $path in produced .xlsx');
}

/// Synthetic stand-in for the backend's May-2026 response payload.
/// Two days × three shifts × one machine — enough to make every cell
/// in the exporter non-trivial without bloating the test.
Map<String, dynamic> _liveMay2026Payload() {
  return {
    'from': '2026-05-01',
    'to': '2026-05-02',
    'days': ['2026-05-01', '2026-05-02'],
    'shifts': [
      {'id': 1, 'code': 'A', 'name': 'Shift A',
        'start_time': '06:00', 'end_time': '14:00'},
      {'id': 2, 'code': 'B', 'name': 'Shift B',
        'start_time': '14:00', 'end_time': '22:00'},
      {'id': 3, 'code': 'C', 'name': 'Shift C',
        'start_time': '22:00', 'end_time': '06:00'},
    ],
    'machines': [
      {'id': 1, 'code': '6AB', 'name': '6AB'},
    ],
    'rows': [
      {
        'machine_id': 1, 'shift_id': 1,
        'daily': [
          {'date': '2026-05-01', 'plan_qty': 100, 'actual_qty': 95,
            'downtime_minutes': 0},
          {'date': '2026-05-02', 'plan_qty': 100, 'actual_qty': 90,
            'downtime_minutes': 10},
        ],
      },
      {
        'machine_id': 1, 'shift_id': 2,
        'daily': [
          {'date': '2026-05-01', 'plan_qty': 100, 'actual_qty': 88,
            'downtime_minutes': 0},
          {'date': '2026-05-02', 'plan_qty': 100, 'actual_qty': 92,
            'downtime_minutes': 0},
        ],
      },
      {
        'machine_id': 1, 'shift_id': 3,
        'daily': [
          {'date': '2026-05-01', 'plan_qty': 100, 'actual_qty': 80,
            'downtime_minutes': 0},
          {'date': '2026-05-02', 'plan_qty': 100, 'actual_qty': 85,
            'downtime_minutes': 0},
        ],
      },
    ],
    // 6 manpower rows — 4 shift-wide (machine_id omitted) + 2 per-machine.
    'manpower': [
      {'date': '2026-05-01', 'shift_id': 1, 'headcount': 4},
      {'date': '2026-05-01', 'shift_id': 2, 'headcount': 4},
      {'date': '2026-05-02', 'shift_id': 1, 'headcount': 4},
      {'date': '2026-05-02', 'shift_id': 2, 'headcount': 3},
      // Per-machine entries (machine_id present).
      {'date': '2026-05-01', 'shift_id': 3, 'machine_id': 1, 'headcount': 3},
      {'date': '2026-05-02', 'shift_id': 3, 'machine_id': 1, 'headcount': 3},
    ],
    'breakdown_hours': [
      {
        'date': '2026-05-02',
        'shift_id': 1,
        'hours': 1.4,
        'by_machine': {'1': 1.4},
      },
    ],
    'cumulative': {
      'plan_qty': 600,
      'actual_qty': 530,
      'achievement_pct': 0.8833,
      'total_downtime_minutes': 10,
      'total_man_hours': 184,
      'total_lost_man_hours': 11.72,
      'lost_pct': 0.0637,
    },
  };
}

String _readSheetXml(List<int> xlsxBytes) {
  final archive = ZipDecoder().decodeBytes(xlsxBytes);
  for (final f in archive.files) {
    if (f.name == 'xl/worksheets/sheet1.xml') {
      final c = f.content;
      return c is List<int> ? utf8.decode(c) : c.toString();
    }
  }
  throw StateError('sheet1.xml missing from .xlsx output');
}
