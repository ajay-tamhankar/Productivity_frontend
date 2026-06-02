import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/dpl_constants.dart';
import '../../models/dpl_reports.dart';

/// One row of the combined downtime export: a single reason on a
/// single day.
class DplDowntimeDateReasonRow {
  final DateTime date;
  final String reason;
  final String category;
  final int totalMinutes;
  final int events;

  const DplDowntimeDateReasonRow({
    required this.date,
    required this.reason,
    required this.category,
    required this.totalMinutes,
    required this.events,
  });

  bool get isPlanned => category == DplDowntimeCategory.planned;
}

/// One date bucket with its per-reason breakdown.
class DplDowntimeDateBucket {
  final DateTime date;
  final List<DplDowntimeDateReasonRow> reasons;

  DplDowntimeDateBucket({required this.date, required this.reasons});

  int get totalMinutes =>
      reasons.fold(0, (sum, r) => sum + r.totalMinutes);
  int get totalEvents => reasons.fold(0, (sum, r) => sum + r.events);
  int get plannedMinutes => reasons
      .where((r) => r.isPlanned)
      .fold(0, (sum, r) => sum + r.totalMinutes);
  int get unplannedMinutes => reasons
      .where((r) => !r.isPlanned)
      .fold(0, (sum, r) => sum + r.totalMinutes);
}

/// Pure-function helpers that turn the raw `DplDowntimeReport` rows
/// (one row per `day × reason`) into the date-bucket structure the
/// UI and the export both use.
class DplDowntimeAggregator {
  const DplDowntimeAggregator._();

  static List<DplDowntimeDateBucket> bucketByDate(DplDowntimeReport report) {
    final byKey = <String, _Bucket>{};
    for (final r in report.rows) {
      final d = r.bucketDate;
      if (d == null) continue;
      final dayKey = DateFormat('yyyy-MM-dd').format(d);
      final bucket = byKey.putIfAbsent(
        dayKey,
        () => _Bucket(date: DateTime(d.year, d.month, d.day)),
      );
      bucket.rows.add(
        DplDowntimeDateReasonRow(
          date: bucket.date,
          reason: r.reasonName.isEmpty ? 'Unspecified' : r.reasonName,
          category: r.category,
          totalMinutes: r.totalMinutes,
          events: r.occurrences,
        ),
      );
    }
    final buckets = <DplDowntimeDateBucket>[];
    for (final b in byKey.values) {
      b.rows.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
      buckets.add(DplDowntimeDateBucket(date: b.date, reasons: b.rows));
    }
    // Newest day first.
    buckets.sort((a, b) => b.date.compareTo(a.date));
    return buckets;
  }
}

class _Bucket {
  final DateTime date;
  final List<DplDowntimeDateReasonRow> rows = [];
  _Bucket({required this.date});
}

/// Client-side Excel + PDF builders for the combined downtime report
/// (date-wise, reasons inside each date).
class DplDowntimeExporter {
  const DplDowntimeExporter._();

  static const List<String> _headers = <String>[
    'Date',
    'Reason',
    'Category',
    'Events',
    'Total Minutes',
    'Total Duration',
  ];

  static Uint8List buildExcel(
    DplDowntimeReport report, {
    DateTime? from,
    DateTime? to,
  }) {
    final excel = Excel.createExcel();
    final dynamic excelDyn = excel;
    const sheetName = 'Downtime';

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

    sheet.appendRow([TextCellValue('Downtime — Date-wise with Reasons')]);
    sheet.appendRow([TextCellValue(_rangeLabel(from, to))]);
    sheet.appendRow([
      TextCellValue(
        'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
      ),
    ]);
    sheet.appendRow(<CellValue?>[]);

    final buckets = DplDowntimeAggregator.bucketByDate(report);
    if (buckets.isEmpty) {
      sheet.appendRow([
        TextCellValue('No downtime logged in this range.'),
      ]);
      final encoded = excel.encode();
      if (encoded == null) {
        throw Exception('Unable to generate Excel file.');
      }
      return Uint8List.fromList(encoded);
    }

    var grandMinutes = 0;
    var grandEvents = 0;

    for (final bucket in buckets) {
      sheet.appendRow([
        TextCellValue('Date: ${dateFmt.format(bucket.date)}'),
      ]);
      sheet.appendRow(_headers.map(TextCellValue.new).toList());

      for (final r in bucket.reasons) {
        sheet.appendRow([
          TextCellValue(dateFmt.format(r.date)),
          TextCellValue(r.reason),
          TextCellValue(r.isPlanned ? 'Planned' : 'Unplanned'),
          TextCellValue(r.events.toString()),
          TextCellValue(r.totalMinutes.toString()),
          TextCellValue(_formatHrsMin(r.totalMinutes)),
        ]);
      }

      sheet.appendRow([
        TextCellValue('Day total'),
        TextCellValue(''),
        TextCellValue(''),
        TextCellValue(bucket.totalEvents.toString()),
        TextCellValue(bucket.totalMinutes.toString()),
        TextCellValue(_formatHrsMin(bucket.totalMinutes)),
      ]);
      sheet.appendRow(<CellValue?>[]);

      grandMinutes += bucket.totalMinutes;
      grandEvents += bucket.totalEvents;
    }

    sheet.appendRow([
      TextCellValue('Grand total'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(grandEvents.toString()),
      TextCellValue(grandMinutes.toString()),
      TextCellValue(_formatHrsMin(grandMinutes)),
    ]);

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Unable to generate Excel file.');
    }
    return Uint8List.fromList(encoded);
  }

  static Future<Uint8List> buildPdf(
    DplDowntimeReport report, {
    DateTime? from,
    DateTime? to,
  }) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('dd MMM yyyy');
    final buckets = DplDowntimeAggregator.bucketByDate(report);

    final grandMinutes =
        buckets.fold<int>(0, (sum, b) => sum + b.totalMinutes);
    final grandEvents =
        buckets.fold<int>(0, (sum, b) => sum + b.totalEvents);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          if (buckets.isEmpty) {
            return <pw.Widget>[
              pw.Text(
                'Downtime — Date-wise with Reasons',
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
                'No downtime logged in this range.',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ];
          }

          return <pw.Widget>[
            pw.Text(
              'Downtime — Date-wise with Reasons',
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
                _pdfKv('Days', buckets.length.toString()),
                _pdfKv('Events', grandEvents.toString()),
                _pdfKv('Total downtime', _formatHrsMin(grandMinutes)),
              ],
            ),
            pw.SizedBox(height: 12),
            for (final bucket in buckets) ...[
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFEAEA),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      dateFmt.format(bucket.date),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '${_formatHrsMin(bucket.totalMinutes)}  •  ${bucket.totalEvents} events',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 4),
              pw.TableHelper.fromTextArray(
                headers: const [
                  'Reason',
                  'Category',
                  'Events',
                  'Total Minutes',
                  'Total Duration',
                  'Share %',
                ],
                data: <List<String>>[
                  for (final r in bucket.reasons)
                    <String>[
                      r.reason,
                      r.isPlanned ? 'Planned' : 'Unplanned',
                      r.events.toString(),
                      r.totalMinutes.toString(),
                      _formatHrsMin(r.totalMinutes),
                      bucket.totalMinutes <= 0
                          ? '-'
                          : '${((r.totalMinutes / bucket.totalMinutes) * 100).toStringAsFixed(1)}%',
                    ],
                  <String>[
                    'Day total',
                    '',
                    bucket.totalEvents.toString(),
                    bucket.totalMinutes.toString(),
                    _formatHrsMin(bucket.totalMinutes),
                    '100.0%',
                  ],
                ],
                border: pw.TableBorder.all(
                  color: PdfColors.grey400,
                  width: 0.4,
                ),
                headerStyle: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFFFF4F4),
                ),
                cellAlignment: pw.Alignment.centerLeft,
              ),
              pw.SizedBox(height: 12),
            ],
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFEEF1F5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Grand total',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_formatHrsMin(grandMinutes)}  •  $grandEvents events  •  ${buckets.length} days',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
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

  static String _formatHrsMin(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _rangeLabel(DateTime? from, DateTime? to) {
    final fmt = DateFormat('dd MMM yyyy');
    if (from == null && to == null) return 'Date range: all data';
    if (from != null && to != null) {
      return 'Date range: ${fmt.format(from)} → ${fmt.format(to)}';
    }
    if (from != null) return 'Date range: from ${fmt.format(from)}';
    return 'Date range: until ${fmt.format(to!)}';
  }
}
