import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/reports/reports_list_screen.dart';

import 'package:productivity_tracker/data/api_services/api_client.dart';
import '../../helpers/mock_api_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('ReportsListScreen displays correct report options', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
        ],
        child: const MaterialApp(
          home: ReportsListScreen(),
        ),
      ),
    );

    // Verify AppBar
    expect(find.text('Reports'), findsWidgets);

    // Verify all report types are present
    expect(find.text('Daily Production Report'), findsOneWidget);
    expect(find.text('Shift-wise Report'), findsOneWidget);
    expect(find.text('Operator Performance Report'), findsOneWidget);
    expect(find.text('Machine Performance Report'), findsOneWidget);
    expect(find.text('Rejection Analysis Report'), findsOneWidget);

    // Tap on the first report to navigate to the detail screen
    await tester.tap(find.text('Daily Production Report'));
    await tester.pumpAndSettle(); // Wait for navigation animation

    // Verify we navigated to ReportDetailScreen
    expect(find.byType(ReportDetailScreen), findsOneWidget);
    expect(find.text('Daily Production Report'), findsWidgets); // Title on detail screen
    
    // Check if PaginatedDataTable exists
    expect(find.byType(PaginatedDataTable), findsOneWidget);
  });
}
