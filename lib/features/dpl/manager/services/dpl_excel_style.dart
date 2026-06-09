import 'package:excel/excel.dart';

/// Default font + size for every DPL Excel export.
///
/// Aptos Narrow is the Microsoft 365 default. Older Excel installs that
/// don't have it will silently substitute Calibri (the same fallback you'd
/// get if no font were set), so this is safe to use unconditionally.
const String dplExcelFontFamily = 'Aptos Narrow';
const int dplExcelFontSize = 10;

/// The default cell style used by every styled row in the DPL exporters.
/// Body cells inherit this; headers/totals can clone-with-bold via
/// [dplBoldCellStyle].
final CellStyle dplDefaultCellStyle = CellStyle(
  fontFamily: dplExcelFontFamily,
  fontSize: dplExcelFontSize,
);

/// Bold variant — used by exporters for the column-header row, day-total,
/// grand-total rows, etc., where the visual hierarchy was previously
/// communicated by Excel's built-in defaults.
final CellStyle dplBoldCellStyle = CellStyle(
  fontFamily: dplExcelFontFamily,
  fontSize: dplExcelFontSize,
  bold: true,
);

/// Appends [cells] as a new row and tags every populated cell with [style]
/// (defaulting to [dplDefaultCellStyle]). Null cells stay null/empty.
///
/// Use this everywhere instead of `sheet.appendRow(...)` so the resulting
/// `.xlsx` opens in Excel with Aptos Narrow 10 by default instead of
/// inheriting the workbook-level Calibri 11.
void appendStyledRow(
  Sheet sheet,
  List<CellValue?> cells, {
  CellStyle? style,
}) {
  sheet.appendRow(cells);
  if (cells.isEmpty) return;
  final rowIndex = sheet.maxRows - 1;
  final s = style ?? dplDefaultCellStyle;
  for (var c = 0; c < cells.length; c++) {
    if (cells[c] == null) continue;
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: rowIndex))
        .cellStyle = s;
  }
}
