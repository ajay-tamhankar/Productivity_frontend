import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:productivity_tracker/features/production_entry/production_entry_screen.dart';

import 'package:productivity_tracker/data/api_services/api_client.dart';
import '../../helpers/mock_api_client.dart';

void main() {
  testWidgets('ProductionEntryScreen displays validation errors and dialog logic', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
        ],
        child: const MaterialApp(
          home: ProductionEntryScreen(),
        ),
      ),
    );

    // Initial render shows loading indicator because master data is async loading.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    
    // Pump and settle to allow MasterData fake network delay to complete
    await tester.pumpAndSettle();

    // Verify main fields are present
    expect(find.text('New Production Entry'), findsOneWidget);
    expect(find.text('Actual Quantity *'), findsOneWidget);
    
    // Scroll to the submit button
    final submitButton = find.text('Submit Entry');
    await tester.ensureVisible(submitButton);

    // Tap submit right away without filling out fields to trigger validation
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify field-level validation triggers
    expect(find.text('Required'), findsWidgets); // Should appear on multiple dropdowns/fields

    // Enter a negative number for actual quantity
    final actualQtyInput = find.byType(TextFormField).first;
    await tester.ensureVisible(actualQtyInput);
    await tester.enterText(actualQtyInput, '-50');
    await tester.pumpAndSettle();
    
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    
    expect(find.text('Must be a valid positive number'), findsOneWidget);

    // Test rejection dialog opens
    final detailsButton = find.text('Details');
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();
    
    expect(find.text('Add Rejection Details'), findsOneWidget);
    expect(find.text('Scratch'), findsOneWidget);
    expect(find.text('Dent'), findsOneWidget);
    
    // Close dialog
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    
    // Verify dialog closed
    expect(find.text('Add Rejection Details'), findsNothing);
  });
}
