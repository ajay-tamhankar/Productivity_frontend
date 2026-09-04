import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/reports/reports_list_screen.dart';

import 'package:productivity_tracker/data/api_services/api_client.dart';
import '../../helpers/mock_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  Future<void> pumpReports(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(MockApiClient())],
        child: const MaterialApp(home: ReportsListScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ReportsListScreen displays correct report options', (
    tester,
  ) async {
    await pumpReports(tester);

    // Verify AppBar
    expect(find.text('Reports Hub'), findsWidgets);

    // Verify all report types are present
    expect(find.text('Daily Production'), findsOneWidget);
    expect(find.text('Shift Performance'), findsOneWidget);
    expect(find.text('Machine Performance'), findsOneWidget);
    expect(find.text('Rejection Analysis'), findsOneWidget);
    expect(find.text('Item Productivity'), findsOneWidget);

    // The cards sit in a lazy ListView, so the last one needs a scroll.
    await tester.scrollUntilVisible(find.text('Downtime Report'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Downtime Report'), findsOneWidget);
  });

  testWidgets('tapping a report opens its detail screen', (tester) async {
    await pumpReports(tester);

    // Tap on the first report to navigate to the detail screen
    await tester.tap(find.text('Daily Production'));
    await tester.pumpAndSettle(); // Wait for navigation animation

    // Verify we navigated to ReportDetailScreen
    expect(find.byType(ReportDetailScreen), findsOneWidget);
    expect(
      find.text('Daily Production'),
      findsWidgets,
    ); // Title on detail screen

    // The detail screen renders entries in a DataTable with its own pager.
    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('ITEM-100'), findsOneWidget);
    expect(find.textContaining('1 records'), findsOneWidget);
  });
}
