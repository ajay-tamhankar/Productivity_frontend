import 'dart:io';
import 'package:excel/excel.dart';

void main() {
  try {
    final correctPath = 'C:/Users/Admin/Downloads/Buffer Creation Plan for Jun-26.xlsx';
    final generatedPath = 'C:/Users/Admin/Downloads/Buffer_Plan_All_Plants_2026_06.xlsx';
    
    print('=== CORRECT FILE — Jun_2026 Sheet (part rows, selected days) ===');
    analyzeCorrectFile(correctPath);
    
    print('\n=== GENERATED FILE — Nexon EV Sheet (all rows, all days) ===');
    analyzeGeneratedFile(generatedPath, 'Nexon EV');
    
    print('\n=== GENERATED FILE — TML PV Sheet ===');
    analyzeGeneratedFile(generatedPath, 'TML PV');
    
    print('\n=== GENERATED FILE — MG Motors Sheet ===');
    analyzeGeneratedFile(generatedPath, 'MG Motors');
  } catch (e, stack) {
    print('Error: $e\n$stack');
  }
}

void analyzeCorrectFile(String path) {
  final file = File(path);
  final bytes = file.readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables['Jun_2026']!;
  
  // Days start from column 2, 5 columns per day.
  // Day 19 = index 18, starts at col 2 + 18*5 = 92
  // Day 26 = index 25, starts at col 2 + 25*5 = 127... but max cols is 127
  // So let's see columns for June 19 through 26
  
  print('Number of days covered: col count / 5 - first 2 = ${(sheet.maxColumns - 2) ~/ 5}');
  
  for (var r = 3; r < sheet.maxRows; r++) {
    final row = sheet.rows[r];
    if (row.isEmpty) continue;
    final partNo = row[0]?.value?.toString() ?? '';
    if (partNo.isEmpty) continue;
    
    // Print June 19 to 26 (indices 18..25)
    final buffer = StringBuffer('Part: $partNo');
    for (var dayIdx = 18; dayIdx <= 25; dayIdx++) {
      final start = 2 + dayIdx * 5;
      if (start + 4 >= row.length) continue;
      
      final tml = toStr(row[start]?.value);
      final ga = toStr(row[start+1]?.value);
      final prod = toStr(row[start+2]?.value);
      final disp = toStr(row[start+3]?.value);
      final plan = toStr(row[start+4]?.value);
      
      buffer.write(' | Jun${dayIdx+1}[TML=$tml GA=$ga Prod=$prod Disp=$disp Plan=$plan]');
    }
    print(buffer.toString());
  }
}

void analyzeGeneratedFile(String path, String sheetName) {
  final file = File(path);
  final bytes = file.readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);
  final sheet = excel.tables[sheetName];
  if (sheet == null) {
    print('Sheet not found: $sheetName');
    return;
  }
  
  print('Rows: ${sheet.maxRows}, Cols: ${sheet.maxColumns}');
  
  for (var r = 3; r < sheet.maxRows; r++) {
    final row = sheet.rows[r];
    if (row.isEmpty) continue;
    final partNo = row[0]?.value?.toString() ?? '';
    if (partNo.isEmpty) continue;
    
    // Print June 19 to 26 (indices 18..25)
    final buffer = StringBuffer('Part: $partNo');
    for (var dayIdx = 18; dayIdx <= 25; dayIdx++) {
      final start = 2 + dayIdx * 5;
      if (start + 4 >= row.length) continue;
      
      final tml = toStr(row[start]?.value);
      final ga = toStr(row[start+1]?.value);
      final prod = toStr(row[start+2]?.value);
      final disp = toStr(row[start+3]?.value);
      final plan = toStr(row[start+4]?.value);
      
      buffer.write(' | Jun${dayIdx+1}[TML=$tml GA=$ga Prod=$prod Disp=$disp Plan=$plan]');
    }
    print(buffer.toString());
  }
}

String toStr(dynamic v) {
  if (v == null) return '-';
  if (v is FormulaCellValue) return 'F';
  return v.toString();
}
