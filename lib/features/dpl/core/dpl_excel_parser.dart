import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/dpl_excel_preview.dart';
import '../models/dpl_machine.dart';
import '../models/dpl_part.dart';

/// Client-side parser for the company "Daily Production Loading Chart"
/// Excel format.
///
/// The format the backend ships looks like this (one machine per sheet):
///
///   Row 1:  Grupo Antolin India Pvt. Ltd                              (merged)
///   Row 2:  Vistar Logitek Pvt. Ltd.                                  (merged)
///   Row 3:  Daily Production Loading Chart                            (merged)
///   Row 4:  (blank)
///   Row 5:  Machine Name: | Nexon SR | | Production Plan for the: | 5-Sep-25
///   Row 6:  (blank)
///   Row 7:  Plan No | Description | Customer Part No. | Material Code | Part Name | Plan Qty | Actual Production | Start Time | End Time
///   Row 8+: data rows
///
/// We:
///   * iterate every sheet
///   * locate the "Machine Name:" label and read the cell to its right
///   * locate the header row by finding the "Plan No" header (any case)
///   * read all data rows below until we hit a fully-empty row
///   * fuzzy-match the machine name against the machines master
///   * match each row's part by `description + machine_name`, falling back
///     to `customer_part_no` exact, then prefix
///
/// Unmatched parts/machines surface as warnings on the preview; the user
/// can still see and edit them before submitting, and submit filters them.
class DplExcelParser {
  const DplExcelParser._();

  static DplExcelPreview parse({
    required Uint8List bytes,
    required List<DplMachine> machines,
    required List<DplPart> parts,
  }) {
    final excel = Excel.decodeBytes(bytes);
    final sections = <DplExcelMachineSection>[];
    final warnings = <DplExcelWarning>[];

    if (excel.tables.isEmpty) {
      warnings.add(const DplExcelWarning(
        message: 'No sheets found in the workbook.',
      ));
      return DplExcelPreview(machines: sections, warnings: warnings);
    }

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName];
      if (sheet == null) continue;
      _parseSheet(
        sheetName: sheetName,
        sheet: sheet,
        machines: machines,
        parts: parts,
        sections: sections,
        warnings: warnings,
      );
    }

    return DplExcelPreview(machines: sections, warnings: warnings);
  }

  static void _parseSheet({
    required String sheetName,
    required Sheet sheet,
    required List<DplMachine> machines,
    required List<DplPart> parts,
    required List<DplExcelMachineSection> sections,
    required List<DplExcelWarning> warnings,
  }) {
    // ---- 1. Find "Machine Name:" + header row ----
    String? machineNameRaw;
    int? headerRowIdx;
    final scanRows = sheet.maxRows < 30 ? sheet.maxRows : 30;
    final scanCols = sheet.maxColumns < 20 ? sheet.maxColumns : 20;

    for (var r = 0; r < scanRows; r++) {
      for (var c = 0; c < scanCols; c++) {
        final v = _cellString(sheet, r, c).toLowerCase();
        if (v.isEmpty) continue;

        if (machineNameRaw == null && v.contains('machine name')) {
          machineNameRaw = _nextNonEmptyOnRow(sheet, r, c + 1);
        }
        if (headerRowIdx == null && v == 'plan no') {
          headerRowIdx = r;
        }
      }
      if (machineNameRaw != null && headerRowIdx != null) break;
    }

    if (headerRowIdx == null) {
      warnings.add(DplExcelWarning(
        message:
            'Sheet "$sheetName": could not find the "Plan No" header row.',
      ));
      return;
    }

    // ---- 2. Match machine ----
    final machineName =
        machineNameRaw == null ? sheetName.trim() : machineNameRaw.trim();
    final machine = _findMachine(machineName, machines);
    if (machine == null) {
      warnings.add(DplExcelWarning(
        message:
            'Sheet "$sheetName": machine "$machineName" not found in master — '
            'add it from Settings → Machines.',
      ));
      return;
    }

    // ---- 3. Map header columns ----
    final colIndex = <String, int>{};
    for (var c = 0; c < sheet.maxColumns; c++) {
      final label = _cellString(sheet, headerRowIdx, c)
          .toLowerCase()
          .replaceAll('.', '')
          .trim();
      if (label.isEmpty) continue;
      colIndex[label] = c;
    }

    final colPlanNo = colIndex['plan no'] ?? -1;
    final colDescription = colIndex['description'] ?? -1;
    final colCustomerPartNo = colIndex['customer part no'] ??
        colIndex['customer part number'] ??
        -1;
    final colPlanQty = colIndex['plan qty'] ?? colIndex['plan quantity'] ?? -1;

    if (colCustomerPartNo < 0 && colDescription < 0) {
      warnings.add(DplExcelWarning(
        message:
            'Sheet "$sheetName": needs a "Customer Part No." or "Description" column.',
      ));
      return;
    }
    if (colPlanQty < 0) {
      warnings.add(DplExcelWarning(
        message: 'Sheet "$sheetName": needs a "Plan Qty" column.',
      ));
      return;
    }

    // ---- 4. Walk the rows below the header ----
    final rows = <DplExcelPlanRow>[];
    var autoPlanNo = 0;
    var autoSeq = 0;
    var emptyStreak = 0;

    for (var r = headerRowIdx + 1; r < sheet.maxRows; r++) {
      final partNoRaw =
          colCustomerPartNo >= 0 ? _cellString(sheet, r, colCustomerPartNo) : '';
      final descRaw =
          colDescription >= 0 ? _cellString(sheet, r, colDescription) : '';
      final qtyRaw =
          colPlanQty >= 0 ? _cellString(sheet, r, colPlanQty) : '';

      final partNo = partNoRaw.trim();
      final desc = descRaw.trim();
      final qty = _parseInt(qtyRaw);

      // Treat the row as empty if both identifier columns are blank.
      if (partNo.isEmpty && desc.isEmpty && qty == 0) {
        emptyStreak++;
        // Two consecutive empty rows → assume end of data (handles the
        // trailing totals row + "Plan Released By" footer block).
        if (emptyStreak >= 2) break;
        continue;
      }
      emptyStreak = 0;

      // Skip rows the backend emits when a part isn't valid for further
      // production (cells contain literal "#N/A").
      if (_isNA(partNo) || _isNA(desc)) {
        warnings.add(DplExcelWarning(
          message:
              'Sheet "$sheetName" row ${r + 1}: skipped — part marked #N/A.',
          row: r + 1,
        ));
        continue;
      }

      if (qty <= 0) {
        warnings.add(DplExcelWarning(
          message:
              'Sheet "$sheetName" row ${r + 1}: skipped — plan qty is missing or 0.',
          row: r + 1,
        ));
        continue;
      }

      // Plan No: respect the cell if present, otherwise auto-increment.
      autoPlanNo++;
      autoSeq++;
      var planNo = autoPlanNo;
      if (colPlanNo >= 0) {
        final pnRaw = _cellString(sheet, r, colPlanNo);
        final pn = _parseInt(pnRaw);
        if (pn > 0) {
          planNo = pn;
          autoPlanNo = pn; // keep auto in sync so blanks below get pn+1
        }
      }

      final part = _findPart(
        description: desc,
        customerPartNo: partNo,
        machineName: machine.name,
        machineCode: machine.code,
        parts: parts,
      );

      rows.add(DplExcelPlanRow(
        planNo: planNo,
        partId: part?.id,
        partNumber: partNo.isNotEmpty
            ? partNo
            : (part?.partNumber ?? ''),
        partDescription: desc.isNotEmpty ? desc : (part?.description ?? ''),
        planQty: qty,
        sequence: autoSeq,
        warning: part == null
            ? 'Part not in master — add it from Settings → Parts'
            : null,
      ));
    }

    if (rows.isEmpty) {
      warnings.add(DplExcelWarning(
        message:
            'Sheet "$sheetName": no usable data rows found below the header.',
      ));
      return;
    }

    sections.add(DplExcelMachineSection(
      machineId: machine.id,
      machineName: machine.name,
      rows: rows,
    ));
  }

  // ---------------------------------------------------------------------------
  // Lookups
  // ---------------------------------------------------------------------------

  static DplMachine? _findMachine(String name, List<DplMachine> machines) {
    if (name.isEmpty || machines.isEmpty) return null;
    final wanted = _normalizeKey(name);

    // Exact normalised match against name OR code.
    for (final m in machines) {
      if (_normalizeKey(m.name) == wanted) return m;
      if (_normalizeKey(m.code) == wanted) return m;
    }

    // Substring fallback (e.g. sheet "Nexon SR Plan" should still match
    // "Nexon SR").
    for (final m in machines) {
      final mn = _normalizeKey(m.name);
      final mc = _normalizeKey(m.code);
      if (mn.isNotEmpty && wanted.contains(mn)) return m;
      if (mc.isNotEmpty && wanted.contains(mc)) return m;
    }

    return null;
  }

  static DplPart? _findPart({
    required String description,
    required String customerPartNo,
    required String machineName,
    required String machineCode,
    required List<DplPart> parts,
  }) {
    if (parts.isEmpty) return null;

    final wantedDesc = description.trim().toUpperCase();
    final wantedPn = customerPartNo.trim();
    final wantedMachine = _normalizeKey(machineName);
    final wantedMachineCode = _normalizeKey(machineCode);

    // 1. description + machine (most reliable when description is a short
    //    code like "102ZX" that recurs across machines).
    if (wantedDesc.isNotEmpty) {
      for (final p in parts) {
        if (p.description.trim().toUpperCase() != wantedDesc) continue;
        final pm = _normalizeKey(_partMachineNameOf(p));
        if (pm.isEmpty ||
            pm == wantedMachine ||
            pm == wantedMachineCode) {
          return p;
        }
      }
      // 1b. description-only (no machine filter) fallback.
      for (final p in parts) {
        if (p.description.trim().toUpperCase() == wantedDesc) return p;
      }
    }

    // 2. customer_part_no exact match.
    if (wantedPn.isNotEmpty) {
      for (final p in parts) {
        if (p.partNumber.trim() == wantedPn) return p;
      }
      // 2b. prefix match either direction (handles truncated masters).
      for (final p in parts) {
        final pn = p.partNumber.trim();
        if (pn.isEmpty) continue;
        if (pn.startsWith(wantedPn) || wantedPn.startsWith(pn)) return p;
      }
    }

    return null;
  }

  /// Pulls the machine-name hint off a [DplPart] when present.
  static String _partMachineNameOf(DplPart p) => p.machineName;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static String _cellString(Sheet sheet, int row, int col) {
    if (row < 0 || col < 0) return '';
    if (row >= sheet.maxRows || col >= sheet.maxColumns) return '';
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    final v = cell.value;
    if (v == null) return '';
    // CellValue subclasses (TextCellValue, IntCellValue, DoubleCellValue,
    // DateCellValue, FormulaCellValue, ...) all override toString() with
    // a useful representation.
    return v.toString();
  }

  static String _nextNonEmptyOnRow(Sheet sheet, int row, int startCol) {
    final maxC = sheet.maxColumns < 20 ? sheet.maxColumns : 20;
    for (var c = startCol; c < maxC; c++) {
      final v = _cellString(sheet, row, c).trim();
      if (v.isNotEmpty) return v;
    }
    return '';
  }

  static int _parseInt(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return 0;
    final n = int.tryParse(t);
    if (n != null) return n;
    final d = double.tryParse(t);
    if (d != null) return d.round();
    return 0;
  }

  static bool _isNA(String s) {
    final t = s.trim().toUpperCase();
    return t == '#N/A' || t == 'N/A' || t == '#REF!';
  }

  /// Lower-cases and strips everything that isn't `[a-z0-9]`, so
  /// "Nexon SR", "nexon_sr", "NEXON-SR" all collapse to "nexonsr".
  static String _normalizeKey(String s) {
    final lower = s.toLowerCase();
    final buf = StringBuffer();
    for (final ch in lower.codeUnits) {
      final isLetter = ch >= 0x61 && ch <= 0x7A;
      final isDigit = ch >= 0x30 && ch <= 0x39;
      if (isLetter || isDigit) buf.writeCharCode(ch);
    }
    return buf.toString();
  }
}
