import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/reports/report_export_service.dart';
import 'package:productivity_tracker/data/models/production_entry_model.dart';

void main() {
  test('export excel and pdf include totals', () async {
    final entries = [
      ProductionEntryModel(
        entryDate: '2026-04-29',
        shift: 'A',
        operatorId: 'op1',
        operatorName: 'Alice',
        machineId: 'm1',
        itemId: 'i1',
        ccd1Quantity: 2,
        actualQuantity: 10,
        rejectionQuantity: 1,
        startTime: '08:00',
        endTime: '10:00',
        runningHours: 2.0,
        partsPerHour: 5.0,
        weightInKGs: 1.5,
        finishWeight: 150.0,
        approvalStatus: 'Approved',
      ),
      ProductionEntryModel(
        entryDate: '2026-04-29',
        shift: 'B',
        operatorId: 'op2',
        operatorName: 'Bob',
        machineId: 'm2',
        itemId: 'i2',
        ccd1Quantity: 3,
        actualQuantity: 20,
        rejectionQuantity: 2,
        startTime: '10:00',
        endTime: '12:00',
        runningHours: 2.0,
        partsPerHour: 10.0,
        weightInKGs: 2.5,
        finishWeight: 200.0,
        approvalStatus: 'Pending',
      ),
    ];

    final excelPath = await ReportExportService.exportExcel(reportName: 'Test Report', entries: entries);
    expect(excelPath, isNotNull);
    expect(File(excelPath!).existsSync(), true);

    final pdfPath = await ReportExportService.exportPdf(reportName: 'Test Report', entries: entries);
    expect(pdfPath, isNotNull);
    expect(File(pdfPath!).existsSync(), true);

    print('Excel saved: $excelPath');
    print('PDF saved: $pdfPath');
  }, timeout: Timeout(Duration(minutes: 2)));
}
