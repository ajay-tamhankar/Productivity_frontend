import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../data/models/production_entry_model.dart';
import 'report_download_stub.dart'
    if (dart.library.html) 'report_download_web.dart'
    if (dart.library.io) 'report_download_io.dart';
import 'report_share_stub.dart'
    if (dart.library.html) 'report_share_web.dart'
    if (dart.library.io) 'report_share_io.dart';

class ReportExportService {
  static const List<String> _headers = <String>[
    'Date',
    'Shift',
    'Operator Name',
    'M/C NO',
    'Item Code',
    'Description',
    'RC Number',
    'Finish Wt',
    'CCD1 Qty',
    'ACTUAL QTY',
    'Rej Qty',
    'IN KGS',
    'Start Time',
    'End Time',
    'RUNNING HRS',
    'parts/Hr',
  ];

  static Future<String?> exportExcel({
    required String reportName,
    required List<ProductionEntryModel> entries,
  }) async {
    final encoded = _buildExcelBytes(reportName, entries);
    return saveReportBytes(
      bytes: encoded,
      fileName: _excelFileName(reportName),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
  }

  static Future<String?> exportPdf({
    required String reportName,
    required List<ProductionEntryModel> entries,
  }) async {
    final bytes = await _buildPdfBytes(reportName, entries);
    return saveReportBytes(
      bytes: bytes,
      fileName: _pdfFileName(reportName),
      mimeType: 'application/pdf',
    );
  }

  static Future<void> shareExcel({
    required String reportName,
    required List<ProductionEntryModel> entries,
  }) async {
    final bytes = _buildExcelBytes(reportName, entries);
    await shareReportBytes(
      bytes: bytes,
      fileName: _excelFileName(reportName),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      text: '$reportName report',
    );
  }

  static Future<void> sharePdf({
    required String reportName,
    required List<ProductionEntryModel> entries,
  }) async {
    final bytes = await _buildPdfBytes(reportName, entries);
    await shareReportBytes(
      bytes: bytes,
      fileName: _pdfFileName(reportName),
      mimeType: 'application/pdf',
      text: '$reportName report',
    );
  }

  static Uint8List _buildExcelBytes(
    String reportName,
    List<ProductionEntryModel> entries,
  ) {
    final excel = Excel.createExcel();
    final dynamic excelDyn = excel;
    final sheetName = _sheetName(reportName);

    String? defaultSheetName;
    try {
      defaultSheetName = excelDyn.getDefaultSheet() as String?;
    } catch (_) {
      defaultSheetName = null;
    }

    if (defaultSheetName != null &&
        defaultSheetName.trim().isNotEmpty &&
        defaultSheetName != sheetName) {
      var renamed = false;
      try {
        excelDyn.rename(defaultSheetName, sheetName);
        renamed = true;
      } catch (_) {
        renamed = false;
      }

      if (!renamed) {
        excel[sheetName];
        try {
          excelDyn.delete(defaultSheetName);
        } catch (_) {
          try {
            final tables = excelDyn.tables;
            if (tables is Map) {
              tables.remove(defaultSheetName);
            }
          } catch (_) {}
        }
      }
    } else {
      excel[sheetName];
    }

    final sheet = excel[sheetName];
    sheet.appendRow(_headers.map(TextCellValue.new).toList());
    for (final row in _rows(entries)) {
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }

    final encoded = excel.encode();
    if (encoded == null) {
      throw Exception('Unable to generate Excel file.');
    }
    return Uint8List.fromList(encoded);
  }

  static Future<Uint8List> _buildPdfBytes(
    String reportName,
    List<ProductionEntryModel> entries,
  ) async {
    final pdf = pw.Document();
    final rows = _rows(entries);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => <pw.Widget>[
          pw.Text(
            '$reportName Export',
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: _headers,
            data: rows,
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            headerDecoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEAF4FF)),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static String _excelFileName(String reportName) =>
      '${_fileSlug(reportName)}_${_stamp()}.xlsx';

  static String _pdfFileName(String reportName) =>
      '${_fileSlug(reportName)}_${_stamp()}.pdf';

  static String _sheetName(String source) {
    final clean = source
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .trim();
    if (clean.isEmpty) return 'Report';
    return clean.length <= 31 ? clean : clean.substring(0, 31);
  }

  static String _fileSlug(String source) {
    final clean = source
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return clean.isEmpty ? 'report' : clean;
  }

  static String _stamp() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  static List<List<String>> _rows(List<ProductionEntryModel> entries) {
    return entries.map((entry) {
      final machine = _display(entry.machineName, entry.machineId);
      final item = _display(entry.itemDescription, entry.itemId);
      final date = _formatDate(entry.entryDate);
      final startTime = _normalizeTime(entry.startTime);
      final endTime = _normalizeTime(entry.endTime);
      final operator = _display(entry.operatorName, entry.operatorId);
      final itemCode = _display(entry.itemCode, entry.itemId);
      final rcNumber = _safe(entry.rcNumber ?? entry.rcNumberId ?? '');
      final finishWt = entry.finishWeight > 0 ? entry.finishWeight.toStringAsFixed(2) : '-';

      return <String>[
        date,
        _safe(entry.shift),
        operator,
        machine,
        itemCode,
        item,
        rcNumber,
        finishWt,
        entry.ccd1Quantity.toString(),
        entry.actualQuantity.toString(),
        entry.rejectionQuantity.toString(),
        entry.weightInKGs.toStringAsFixed(2),
        startTime,
        endTime,
        entry.runningHours.toStringAsFixed(2),
        entry.partsPerHour.toStringAsFixed(2),
      ];
    }).toList();
  }

  static String _safe(String value) {
    final text = value.trim();
    return text.isEmpty ? '-' : text;
  }

  static String _display(String? preferred, String fallback) {
    final primary = (preferred ?? '').trim();
    if (primary.isNotEmpty) return primary;
    final alt = fallback.trim();
    return alt.isEmpty ? '-' : alt;
  }

  static String _formatDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return _safe(rawDate);
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  static String _normalizeTime(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '-';

    final hhmm = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');
    if (hhmm.hasMatch(text)) return text;

    final iso = RegExp(r'T([01]\d|2[0-3]):([0-5]\d)').firstMatch(text);
    if (iso != null) return '${iso.group(1)}:${iso.group(2)}';

    final parsed = DateTime.tryParse(text);
    if (parsed != null) return DateFormat('HH:mm').format(parsed);

    return text;
  }
}
