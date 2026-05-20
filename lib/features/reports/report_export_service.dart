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
    'RC Number',
    'Item Code',
    'Description',
    'Finish Wt',
    'CCD1 Qty',
    'ACTUAL QTY',
    'Rej Qty',
    'IN KGS',
    'Start Time',
    'End Time',
    'RUNNING HRS',
    'parts/Hr',
    'Status',
  ];
  static const List<String> _productivityHeaders = <String>[
    'Name',
    'Pieces/Hr',
    'KG/Hr',
    'Total Qty',
    'Total KG',
    'Running Hrs',
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
    if (_isItemProductivityReport(reportName)) {
      _appendProductivityExcel(sheet, entries);
    } else {
      sheet.appendRow(_headers.map(TextCellValue.new).toList());
      for (final row in _rows(entries)) {
        sheet.appendRow(row.map(TextCellValue.new).toList());
      }
      // append totals row for numeric columns
      final totals = _mainTotalsRowFromEntries(entries);
      if (totals.isNotEmpty) {
        sheet.appendRow(totals.map(TextCellValue.new).toList());
      }
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => <pw.Widget>[
          pw.Text(
            '$reportName Export',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated on ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 10),
          if (_isItemProductivityReport(reportName))
            ..._productivityPdfWidgets(entries)
          else
            pw.TableHelper.fromTextArray(
              headers: _headers,
              data: <List<String>>[..._rows(entries), _mainTotalsRowFromEntries(entries)],
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFEAF4FF),
              ),
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
    final clean = source.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
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

  static String _stamp() =>
      DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  static bool _isItemProductivityReport(String reportName) =>
      reportName.trim().toLowerCase() == 'item productivity';

  static void _appendProductivityExcel(
    Sheet sheet,
    List<ProductionEntryModel> entries,
  ) {
    final summaries = _productivitySummaries(entries);
    if (summaries.isEmpty) {
      sheet.appendRow([TextCellValue('No productivity data available.')]);
      return;
    }

    for (final summary in summaries) {
      sheet.appendRow([TextCellValue('Item: ${summary.itemName}')]);
      sheet.appendRow([TextCellValue('Machine Productivity')]);
      sheet.appendRow(_productivityHeaders.map(TextCellValue.new).toList());
      for (final row in summary.machines) {
        sheet.appendRow(_productivityRow(row).map(TextCellValue.new).toList());
      }
      // machines totals
      final mTotals = _productivityTotalsRow(summary.machines);
      if (mTotals.isNotEmpty) {
        sheet.appendRow(mTotals.map(TextCellValue.new).toList());
      }
      sheet.appendRow(<CellValue?>[]);

      sheet.appendRow([TextCellValue('Operator Productivity')]);
      sheet.appendRow(_productivityHeaders.map(TextCellValue.new).toList());
      for (final row in summary.operators) {
        sheet.appendRow(_productivityRow(row).map(TextCellValue.new).toList());
      }
      // operators totals
      final oTotals = _productivityTotalsRow(summary.operators);
      if (oTotals.isNotEmpty) {
        sheet.appendRow(oTotals.map(TextCellValue.new).toList());
      }
      sheet.appendRow(<CellValue?>[]);
    }
  }

  static List<pw.Widget> _productivityPdfWidgets(
    List<ProductionEntryModel> entries,
  ) {
    final summaries = _productivitySummaries(entries);
    if (summaries.isEmpty) {
      return [
        pw.Text(
          'No productivity data available. Entries need running hours to calculate productivity.',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ];
    }

    return summaries.expand((summary) {
      return <pw.Widget>[
        pw.Text(
          'Item: ${summary.itemName}',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 6),
        _productivityPdfTable('Machine Productivity', summary.machines),
        pw.SizedBox(height: 8),
        _productivityPdfTable('Operator Productivity', summary.operators),
        pw.SizedBox(height: 14),
      ];
    }).toList();
  }

  static pw.Widget _productivityPdfTable(
    String title,
    List<_ProductivityExportRow> rows,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.TableHelper.fromTextArray(
          headers: _productivityHeaders,
          data: <List<String>>[...rows.map(_productivityRow), _productivityTotalsRow(rows)],
          border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          headerStyle: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
          ),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFEAF4FF),
          ),
          cellAlignment: pw.Alignment.centerLeft,
        ),
      ],
    );
  }

  static List<String> _productivityRow(_ProductivityExportRow row) {
    return <String>[
      row.name,
      row.piecesPerHour.toStringAsFixed(2),
      row.kgPerHour.toStringAsFixed(2),
      row.pieces.toString(),
      row.kg.toStringAsFixed(2),
      row.hours.toStringAsFixed(2),
    ];
  }

  static List<String> _productivityTotalsRow(List<_ProductivityExportRow> rows) {
    if (rows.isEmpty) return <String>[];
    int pieces = 0;
    double kg = 0;
    double hours = 0;
    for (final r in rows) {
      pieces += r.pieces;
      kg += r.kg;
      hours += r.hours;
    }
    return <String>[
      'Totals',
      '', // Pieces/Hr total not meaningful
      '', // KG/Hr total not meaningful
      pieces.toString(),
      kg.toStringAsFixed(2),
      hours.toStringAsFixed(2),
    ];
  }

  static List<String> _mainTotalsRowFromEntries(List<ProductionEntryModel> entries) {
    if (entries.isEmpty) return <String>[];

    int totalCcd1 = 0;
    int totalActual = 0;
    int totalRej = 0;
    double totalKg = 0;
    double totalRunning = 0;
    double totalPartsPerHour = 0;

    for (final e in entries) {
      totalCcd1 += e.ccd1Quantity;
      totalActual += e.actualQuantity;
      totalRej += e.rejectionQuantity;
      totalKg += e.weightInKGs;
      totalRunning += e.runningHours;
      totalPartsPerHour += e.partsPerHour;
    }

    final row = List<String>.filled(_headers.length, '');
    row[0] = 'Totals';
    row[7] = '';
    row[8] = totalCcd1.toString();
    row[9] = totalActual.toString();
    row[10] = totalRej.toString();
    row[11] = totalKg.toStringAsFixed(2);
    row[12] = '';
    row[13] = '';
    row[14] = totalRunning.toStringAsFixed(2);
    row[15] = totalPartsPerHour.toStringAsFixed(2);
    return row;
  }

  static List<_ItemProductivityExportSummary> _productivitySummaries(
    List<ProductionEntryModel> entries,
  ) {
    final byItem = <String, _ItemProductivityExportSummary>{};

    for (final entry in entries) {
      final hours = entry.runningHours;
      if (hours <= 0) continue;

      final itemName = _display(entry.itemDescription, entry.itemId);
      final summary = byItem.putIfAbsent(
        itemName.toLowerCase(),
        () => _ItemProductivityExportSummary(itemName: itemName),
      );
      final kg = entry.weightInKGs > 0
          ? entry.weightInKGs
          : (entry.actualQuantity * entry.finishWeight) / 1000;

      summary.addMachine(
        name: _display(entry.machineName, entry.machineId),
        pieces: entry.actualQuantity,
        kg: kg,
        hours: hours,
      );
      summary.addOperator(
        name: _display(entry.operatorName, entry.operatorId),
        pieces: entry.actualQuantity,
        kg: kg,
        hours: hours,
      );
    }

    final summaries = byItem.values.toList()
      ..sort((a, b) => a.itemName.compareTo(b.itemName));
    for (final summary in summaries) {
      summary.sortRows();
    }
    return summaries;
  }

  static List<List<String>> _rows(List<ProductionEntryModel> entries) {
    return entries.map((entry) {
      final machine = _display(entry.machineName, entry.machineId);
      final item = _display(entry.itemDescription, entry.itemId);
      final date = _formatDate(entry.entryDate);
      final startTime = _normalizeTime(entry.startTime);
      final endTime = _normalizeTime(entry.endTime);
      final operator = _display(entry.operatorName, entry.operatorId);
      final rcNumber = _safe(entry.rcNumber ?? '');
      final itemCode = _display(entry.itemCode, entry.itemId);
      final finishWt = entry.finishWeight > 0
          ? entry.finishWeight.toStringAsFixed(2)
          : '-';

      return <String>[
        date,
        _safe(entry.shift),
        operator,
        machine,
        rcNumber,
        itemCode,
        item,
        finishWt,
        entry.ccd1Quantity.toString(),
        entry.actualQuantity.toString(),
        entry.rejectionQuantity.toString(),
        entry.weightInKGs.toStringAsFixed(2),
        startTime,
        endTime,
        entry.runningHours.toStringAsFixed(2),
        entry.partsPerHour.toStringAsFixed(2),
        _safe(entry.approvalStatus ?? ''),
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

class _ItemProductivityExportSummary {
  final String itemName;
  final Map<String, _ProductivityExportRow> _machines = {};
  final Map<String, _ProductivityExportRow> _operators = {};

  _ItemProductivityExportSummary({required this.itemName});

  List<_ProductivityExportRow> get machines => _machines.values.toList();
  List<_ProductivityExportRow> get operators => _operators.values.toList();

  void addMachine({
    required String name,
    required int pieces,
    required double kg,
    required double hours,
  }) {
    _add(_machines, name: name, pieces: pieces, kg: kg, hours: hours);
  }

  void addOperator({
    required String name,
    required int pieces,
    required double kg,
    required double hours,
  }) {
    _add(_operators, name: name, pieces: pieces, kg: kg, hours: hours);
  }

  void _add(
    Map<String, _ProductivityExportRow> rows, {
    required String name,
    required int pieces,
    required double kg,
    required double hours,
  }) {
    final key = name.toLowerCase();
    final row = rows.putIfAbsent(key, () => _ProductivityExportRow(name: name));
    row.add(pieces: pieces, kg: kg, hours: hours);
  }

  void sortRows() {
    final sortedMachines = machines
      ..sort((a, b) => b.piecesPerHour.compareTo(a.piecesPerHour));
    final sortedOperators = operators
      ..sort((a, b) => b.piecesPerHour.compareTo(a.piecesPerHour));

    _machines
      ..clear()
      ..addEntries(sortedMachines.map((row) => MapEntry(row.name, row)));
    _operators
      ..clear()
      ..addEntries(sortedOperators.map((row) => MapEntry(row.name, row)));
  }
}

class _ProductivityExportRow {
  final String name;
  int pieces = 0;
  double kg = 0;
  double hours = 0;

  _ProductivityExportRow({required this.name});

  double get piecesPerHour => hours <= 0 ? 0 : pieces / hours;
  double get kgPerHour => hours <= 0 ? 0 : kg / hours;

  void add({required int pieces, required double kg, required double hours}) {
    this.pieces += pieces;
    this.kg += kg;
    this.hours += hours;
  }
}
