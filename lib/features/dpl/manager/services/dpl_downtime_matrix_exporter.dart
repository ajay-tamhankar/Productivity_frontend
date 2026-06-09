import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

import '../../models/dpl_downtime_event_detail.dart';
import 'dpl_excel_style.dart';

/// Pivot view of downtime events shaped exactly like the production
/// "Down Time Reason" spreadsheet:
///
///   `Machine | Reason | <date 1> | <date 2> | ... | Grand Total`
///   ...
///   Grand Total row across all rows
///   Total-duration footer row formatted as "X hr Y min"
///
/// Built entirely client-side from the flat events feed
/// (`/manager/reports/downtime/events`) — no extra backend endpoint
/// is needed.
class DplDowntimeMatrix {
  /// All dates that have at least one logged event, ascending. The CSV
  /// reference shows oldest first, so we preserve that order.
  final List<DateTime> dates;

  /// One row per (machine × reason) combination, grouped by machine.
  final List<DplDowntimeMatrixRow> rows;

  /// Minutes per date column, indexed by [dates] position.
  final List<int> dateTotals;

  /// Sum of every cell. Matches the bottom-right "Grand Total" cell.
  final int grandTotal;

  const DplDowntimeMatrix({
    required this.dates,
    required this.rows,
    required this.dateTotals,
    required this.grandTotal,
  });

  bool get isEmpty => rows.isEmpty;

  factory DplDowntimeMatrix.fromEvents(List<DplDowntimeEventDetail> events) {
    if (events.isEmpty) {
      return const DplDowntimeMatrix(
        dates: [],
        rows: [],
        dateTotals: [],
        grandTotal: 0,
      );
    }

    // Collect every distinct local date that appears at least once.
    // Fall back to the IST wall-clock date when `local_date` is null
    // so a row can never silently disappear.
    final dateKeys = <String, DateTime>{};
    for (final e in events) {
      final d = _eventLocalDate(e);
      final key = DateFormat('yyyy-MM-dd').format(d);
      dateKeys.putIfAbsent(key, () => d);
    }
    final dates = dateKeys.values.toList()
      ..sort((a, b) => a.compareTo(b));
    final dateIndex = <String, int>{
      for (var i = 0; i < dates.length; i++)
        DateFormat('yyyy-MM-dd').format(dates[i]): i,
    };

    // Aggregate (machine, reason) → per-date minutes.
    final byKey = <String, _RowAcc>{};
    for (final e in events) {
      final machine = e.machineName.trim().isEmpty
          ? 'Machine #${e.machineId}'
          : e.machineName.trim();
      final reason = e.reasonName.trim().isEmpty
          ? 'Unspecified'
          : e.reasonName.trim();
      final key = '$machine$reason';
      final acc = byKey.putIfAbsent(
        key,
        () => _RowAcc(
          machineName: machine,
          reasonName: reason,
          category: e.category,
          minutesByDate: List<int>.filled(dates.length, 0),
        ),
      );
      final di = dateIndex[DateFormat('yyyy-MM-dd').format(_eventLocalDate(e))];
      if (di == null) continue;
      acc.minutesByDate[di] += e.durationMinutes;
    }

    // Sort: machine asc, then reason asc — mirrors the CSV grouping.
    final accs = byKey.values.toList()
      ..sort((a, b) {
        final byMachine =
            a.machineName.toLowerCase().compareTo(b.machineName.toLowerCase());
        if (byMachine != 0) return byMachine;
        return a.reasonName
            .toLowerCase()
            .compareTo(b.reasonName.toLowerCase());
      });

    final rows = <DplDowntimeMatrixRow>[];
    final dateTotals = List<int>.filled(dates.length, 0);
    var grand = 0;
    for (final a in accs) {
      var rowTotal = 0;
      for (var i = 0; i < dates.length; i++) {
        final v = a.minutesByDate[i];
        rowTotal += v;
        dateTotals[i] += v;
      }
      grand += rowTotal;
      rows.add(DplDowntimeMatrixRow(
        machineName: a.machineName,
        reasonName: a.reasonName,
        category: a.category,
        minutesByDate: a.minutesByDate,
        rowTotal: rowTotal,
      ));
    }

    return DplDowntimeMatrix(
      dates: dates,
      rows: rows,
      dateTotals: dateTotals,
      grandTotal: grand,
    );
  }

  static DateTime _eventLocalDate(DplDowntimeEventDetail e) {
    final local = e.localDate;
    if (local != null) return DateTime(local.year, local.month, local.day);
    // Derive from start_time in Asia/Kolkata wall-clock (UTC + 5:30).
    final ist = e.startTime.toUtc().add(const Duration(hours: 5, minutes: 30));
    return DateTime(ist.year, ist.month, ist.day);
  }
}

class DplDowntimeMatrixRow {
  final String machineName;
  final String reasonName;
  final String category;
  final List<int> minutesByDate;
  final int rowTotal;

  const DplDowntimeMatrixRow({
    required this.machineName,
    required this.reasonName,
    required this.category,
    required this.minutesByDate,
    required this.rowTotal,
  });
}

class _RowAcc {
  final String machineName;
  final String reasonName;
  final String category;
  final List<int> minutesByDate;

  _RowAcc({
    required this.machineName,
    required this.reasonName,
    required this.category,
    required this.minutesByDate,
  });
}

/// Excel + CSV builders for the [DplDowntimeMatrix], formatted to match
/// the reference "Down Time Reason" spreadsheet 1:1.
class DplDowntimeMatrixExporter {
  const DplDowntimeMatrixExporter._();

  static Uint8List buildExcel(
    DplDowntimeMatrix matrix, {
    DateTime? from,
    DateTime? to,
  }) {
    final excel = Excel.createExcel();
    final dynamic excelDyn = excel;
    const sheetName = 'Down Time Reason';

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

    final dateHeader = DateFormat('dd-MMM');

    // Header row: Machine Name | Down Time Reason | <date 1> ... | Grand Total
    final header = <CellValue?>[
      TextCellValue('Machine Name'),
      TextCellValue('Down Time Reason'),
      for (final d in matrix.dates) TextCellValue(dateHeader.format(d)),
      TextCellValue('Grand Total'),
    ];
    appendStyledRow(sheet,header);

    if (matrix.isEmpty) {
      appendStyledRow(sheet,<CellValue?>[
        TextCellValue('No downtime events in this range.'),
      ]);
      final encoded = excel.encode();
      if (encoded == null) {
        throw Exception('Unable to generate Excel file.');
      }
      return Uint8List.fromList(encoded);
    }

    String? lastMachine;
    for (final row in matrix.rows) {
      final cells = <CellValue?>[
        TextCellValue(row.machineName == lastMachine ? '' : row.machineName),
        TextCellValue(row.reasonName),
        for (final v in row.minutesByDate)
          v == 0 ? null : IntCellValue(v),
        IntCellValue(row.rowTotal),
      ];
      appendStyledRow(sheet,cells);
      lastMachine = row.machineName;
    }

    // Grand-total row.
    appendStyledRow(sheet,<CellValue?>[
      null,
      TextCellValue('Grand Total'),
      for (final v in matrix.dateTotals) IntCellValue(v),
      IntCellValue(matrix.grandTotal),
    ]);

    // Blank spacer row.
    appendStyledRow(sheet,<CellValue?>[]);

    // Formatted "X hr Y min" duration row under the grand-total row.
    appendStyledRow(sheet,<CellValue?>[
      null,
      null,
      for (final v in matrix.dateTotals)
        TextCellValue(_formatHrsMin(v)),
      null,
    ]);

    // Range banner appended at the bottom so it doesn't disturb the
    // pivot header row a user might paste-into-another-sheet.
    appendStyledRow(sheet,<CellValue?>[]);
    appendStyledRow(sheet,<CellValue?>[
      TextCellValue('Range: ${_rangeLabel(from, to)}'),
    ]);
    appendStyledRow(sheet,<CellValue?>[
      TextCellValue(
        'Generated ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      ),
    ]);

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Unable to generate Excel file.');
    }
    return Uint8List.fromList(encoded);
  }

  static Uint8List buildCsv(
    DplDowntimeMatrix matrix, {
    DateTime? from,
    DateTime? to,
  }) {
    final dateHeader = DateFormat('dd-MMM');
    final buf = StringBuffer();

    final header = <String>[
      'Machine Name',
      'Down Time Reason',
      for (final d in matrix.dates) dateHeader.format(d),
      'Grand Total',
    ];
    buf.writeln(header.map(_csvCell).join(','));

    if (matrix.isEmpty) {
      buf.writeln('No downtime events in this range.');
    } else {
      String? lastMachine;
      for (final row in matrix.rows) {
        final cells = <String>[
          row.machineName == lastMachine ? '' : row.machineName,
          row.reasonName,
          for (final v in row.minutesByDate) v == 0 ? '' : v.toString(),
          row.rowTotal.toString(),
        ];
        buf.writeln(cells.map(_csvCell).join(','));
        lastMachine = row.machineName;
      }
      final totalCells = <String>[
        '',
        'Grand Total',
        for (final v in matrix.dateTotals) v.toString(),
        matrix.grandTotal.toString(),
      ];
      buf.writeln(totalCells.map(_csvCell).join(','));
      buf.writeln(',,${List.filled(matrix.dates.length + 1, '').join(',')}');
      final durationCells = <String>[
        '',
        '',
        for (final v in matrix.dateTotals) _formatHrsMin(v),
        '',
      ];
      buf.writeln(durationCells.map(_csvCell).join(','));
    }

    return Uint8List.fromList(buf.toString().codeUnits);
  }

  static String _csvCell(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    if (!needsQuotes) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  static String _formatHrsMin(int minutes) {
    if (minutes <= 0) return '0 hr 0 min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h hr $m min';
  }

  static String _rangeLabel(DateTime? from, DateTime? to) {
    final fmt = DateFormat('dd MMM yyyy');
    if (from == null && to == null) return 'all data';
    if (from != null && to != null) {
      return '${fmt.format(from)} → ${fmt.format(to)}';
    }
    if (from != null) return 'from ${fmt.format(from)}';
    return 'until ${fmt.format(to!)}';
  }
}
