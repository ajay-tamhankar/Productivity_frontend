import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../providers/dpl_daily_log_report_provider.dart';

/// Client-side Excel + PDF builders for the Daily Log report. Pure
/// functions over a [DplDailyLogReport] payload — same shape the
/// screen renders, so the exported files mirror the UI exactly.
class DplDailyLogExporter {
  const DplDailyLogExporter._();

  static const List<String> _headers = <String>[
    'Date',
    'Plan #',
    'Machine',
    'Item / Part',
    'Shift',
    'Status',
    'Plan Qty',
    'Actual Qty',
    'Achievement %',
    'Start',
    'End',
    'Total Time',
    'Effective Run',
    'Downtime',
    'Reason / Remarks',
  ];

  static Uint8List buildExcel(
    DplDailyLogReport report, {
    DateTime? from,
    DateTime? to,
  }) {
    final excel = Excel.createExcel();
    final dynamic excelDyn = excel;
    const sheetName = 'Daily Log';

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

    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');

    sheet.appendRow([TextCellValue('Daily Production Log')]);
    sheet.appendRow([TextCellValue(_rangeLabel(from, to))]);
    sheet.appendRow([
      TextCellValue(
        'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      ),
    ]);
    sheet.appendRow(<CellValue?>[]);

    if (report.rows.isEmpty) {
      sheet.appendRow([TextCellValue('No plans in this range.')]);
      final encoded = excel.encode();
      if (encoded == null) {
        throw Exception('Unable to generate Excel file.');
      }
      return Uint8List.fromList(encoded);
    }

    // Group by date for headers; the rows themselves stay sortable so
    // pivoting later still works.
    final groups = _groupByDate(report);
    var grandPlan = 0;
    var grandActual = 0;
    var grandRun = 0;
    var grandDowntime = 0;

    for (final group in groups) {
      sheet.appendRow([
        TextCellValue('Date: ${dateFmt.format(group.date)}'),
      ]);
      sheet.appendRow(_headers.map(TextCellValue.new).toList());
      var dayPlan = 0;
      var dayActual = 0;
      var dayRun = 0;
      var dayDowntime = 0;

      for (final row in group.rows) {
        dayPlan += row.planQty;
        dayActual += row.actualQty;
        dayRun += row.runMinutes ?? 0;
        dayDowntime += row.downtimeMinutes;

        sheet.appendRow([
          TextCellValue(dateFmt.format(row.planDate)),
          TextCellValue(row.planNo == null ? '#${row.planId}' : '#${row.planNo}'),
          TextCellValue(row.machineName),
          TextCellValue(row.partLabel),
          TextCellValue(row.shiftLabel),
          TextCellValue(_statusLabel(row.status)),
          TextCellValue(row.planQty.toString()),
          TextCellValue(row.actualQty.toString()),
          TextCellValue('${(row.completionPct * 100).toStringAsFixed(1)}%'),
          TextCellValue(
            row.startTime == null ? '-' : timeFmt.format(row.startTime!),
          ),
          TextCellValue(
            row.endTime == null ? '-' : timeFmt.format(row.endTime!),
          ),
          TextCellValue(_formatMin(row.runMinutes)),
          TextCellValue(_formatMin(row.effectiveRunMinutes)),
          TextCellValue(_formatMin(row.downtimeMinutes)),
          TextCellValue(row.reasonOrRemarks),
        ]);
      }

      sheet.appendRow([
        TextCellValue('Day total'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(dayPlan.toString()),
        TextCellValue(dayActual.toString()),
        TextCellValue(
          dayPlan <= 0
              ? '-'
              : '${((dayActual / dayPlan) * 100).clamp(0, 999).toStringAsFixed(1)}%',
        ),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(_formatMin(dayRun)),
        TextCellValue(_formatMin(dayRun - dayDowntime)),
        TextCellValue(_formatMin(dayDowntime)),
        TextCellValue(''),
      ]);
      sheet.appendRow(<CellValue?>[]);

      grandPlan += dayPlan;
      grandActual += dayActual;
      grandRun += dayRun;
      grandDowntime += dayDowntime;
    }

    sheet.appendRow([
      TextCellValue('Grand total'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(grandPlan.toString()),
      TextCellValue(grandActual.toString()),
      TextCellValue(
        grandPlan <= 0
            ? '-'
            : '${((grandActual / grandPlan) * 100).clamp(0, 999).toStringAsFixed(1)}%',
      ),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(_formatMin(grandRun)),
      TextCellValue(_formatMin(grandRun - grandDowntime)),
      TextCellValue(_formatMin(grandDowntime)),
      TextCellValue(''),
    ]);

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Unable to generate Excel file.');
    }
    return Uint8List.fromList(encoded);
  }

  static Future<Uint8List> buildPdf(
    DplDailyLogReport report, {
    DateTime? from,
    DateTime? to,
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('HH:mm');
    final groups = _groupByDate(report);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a3.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          if (report.rows.isEmpty) {
            return <pw.Widget>[
              pw.Text(
                'Daily Production Log',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                _rangeLabel(from, to),
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'No plans in this range.',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ];
          }

          var grandPlan = 0;
          var grandActual = 0;
          var grandRun = 0;
          var grandDowntime = 0;
          for (final g in groups) {
            for (final r in g.rows) {
              grandPlan += r.planQty;
              grandActual += r.actualQty;
              grandRun += r.runMinutes ?? 0;
              grandDowntime += r.downtimeMinutes;
            }
          }

          return <pw.Widget>[
            pw.Text(
              'Daily Production Log',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              _rangeLabel(from, to),
              style: const pw.TextStyle(fontSize: 10),
            ),
            pw.Text(
              'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 9),
            ),
            pw.SizedBox(height: 10),
            pw.Wrap(
              spacing: 18,
              runSpacing: 6,
              children: [
                _pdfKv('Plan total', grandPlan.toString()),
                _pdfKv('Actual total', grandActual.toString()),
                _pdfKv(
                  'Achievement',
                  grandPlan <= 0
                      ? '-'
                      : '${((grandActual / grandPlan) * 100).clamp(0, 999).toStringAsFixed(1)}%',
                ),
                _pdfKv('Run time', _formatMin(grandRun)),
                _pdfKv('Downtime', _formatMin(grandDowntime)),
              ],
            ),
            pw.SizedBox(height: 12),
            for (final group in groups) ...[
              pw.Text(
                dateFmt.format(group.date),
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: _headers,
                data: <List<String>>[
                  for (final row in group.rows)
                    <String>[
                      dateFmt.format(row.planDate),
                      row.planNo == null
                          ? '#${row.planId}'
                          : '#${row.planNo}',
                      row.machineName,
                      row.partLabel,
                      row.shiftLabel,
                      _statusLabel(row.status),
                      row.planQty.toString(),
                      row.actualQty.toString(),
                      '${(row.completionPct * 100).toStringAsFixed(1)}%',
                      row.startTime == null
                          ? '-'
                          : timeFmt.format(row.startTime!),
                      row.endTime == null
                          ? '-'
                          : timeFmt.format(row.endTime!),
                      _formatMin(row.runMinutes),
                      _formatMin(row.effectiveRunMinutes),
                      _formatMin(row.downtimeMinutes),
                      row.reasonOrRemarks,
                    ],
                ],
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.4,
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEAF1FF),
                ),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 12),
            ],
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfKv(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static String _formatMin(int? minutes) {
    if (minutes == null) return '-';
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'pending':
        return 'Pending';
      default:
        return status.isEmpty ? '-' : status;
    }
  }

  static String _rangeLabel(DateTime? from, DateTime? to) {
    final fmt = DateFormat('dd MMM yyyy');
    if (from == null && to == null) return 'Date range: all dates';
    if (from != null && to != null) {
      return 'Date range: ${fmt.format(from)} → ${fmt.format(to)}';
    }
    if (from != null) return 'Date range: from ${fmt.format(from)}';
    return 'Date range: until ${fmt.format(to!)}';
  }

  static List<_DailyLogGroup> _groupByDate(DplDailyLogReport report) {
    final byKey = <String, _DailyLogGroup>{};
    for (final row in report.rows) {
      final d = row.planDate;
      final date = DateTime(d.year, d.month, d.day);
      final key = DateFormat('yyyy-MM-dd').format(date);
      final group = byKey.putIfAbsent(
        key,
        () => _DailyLogGroup(date: date),
      );
      group.rows.add(row);
    }
    final list = byKey.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return list;
  }
}

class _DailyLogGroup {
  final DateTime date;
  final List<DplDailyLogRow> rows = [];
  _DailyLogGroup({required this.date});
}
