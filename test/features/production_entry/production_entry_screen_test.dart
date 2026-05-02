import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:productivity_tracker/features/production_entry/production_entry_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_tracker/data/api_services/api_client.dart';
import '../../helpers/mock_api_client.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ProductionEntryScreen Phase 1 validation (Start Shift)', (WidgetTester tester) async {
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

    await tester.pumpAndSettle();

    // Verify Phase 1 fields
    expect(find.text('New Production Entry'), findsOneWidget);
    expect(find.text('Start Shift'), findsOneWidget);
    
    // Phase 2 fields should be hidden
    expect(find.text('Actual Quantity *'), findsNothing);
    
    // Tap Start Shift without fields filled
    final startButton = find.text('Start Shift');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Validation should trigger
    expect(find.text('Machine is required.'), findsOneWidget);
    expect(find.text('Item is required.'), findsOneWidget);
    expect(find.text('Start Time is required.'), findsOneWidget);
  });

  testWidgets('ProductionEntryScreen Phase 2 validation and dialog logic (End Shift)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Mock SharedPreferences to be in Phase 2
    SharedPreferences.setMockInitialValues({
      'production_started': true,
      'prod_shift': 'A',
      'prod_machineId': 'M1',
      'prod_itemId': 'I1',
      'prod_customerId': 'C1',
      'prod_st_hour': 8,
      'prod_st_min': 0,
      'prod_itemWeightG': 100.0,
    });

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

    await tester.pumpAndSettle();

    // Phase 2 fields should be visible
    expect(find.text('Actual Quantity *'), findsOneWidget);
    expect(find.text('End Shift & Submit'), findsOneWidget);

    final submitButton = find.text('End Shift & Submit');
    await tester.ensureVisible(submitButton);

    // Tap submit right away to trigger validation
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify numeric field validation trigger (Actual Quantity)
    expect(find.text('Actual Quantity is required.'), findsWidgets);

    // Enter non-digit letters (stripped by inputFormatter -> empty field)
    final actualQtyInput = find.widgetWithText(TextFormField, 'Actual Quantity *').first;
    await tester.ensureVisible(actualQtyInput);
    await tester.enterText(actualQtyInput, 'invalid');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Actual Quantity is required.'), findsWidgets);

    // Test rejection dialog opens
    final detailsButton = find.text('Rejection Details');
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();
    
    expect(find.text('Rejection Details'), findsWidgets);
    expect(find.text('Scratch'), findsOneWidget);
    expect(find.text('Dent'), findsOneWidget);
    
    // Close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    
    // Verify dialog closed by checking for 'Cancel' button not shown
    expect(find.text('Cancel'), findsNothing);

    // Test Downtime toggle and Validation
    final switchFinder = find.widgetWithText(SwitchListTile, 'Add Machine Downtime');
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    // Select an End Time so _timeError passes the end-time-null check
    final endTimeButton = find.widgetWithText(OutlinedButton, 'End Time *').first;
    await tester.ensureVisible(endTimeButton);
    await tester.tap(endTimeButton);
    await tester.pumpAndSettle();
    
    // Tap OK on TimePicker dial
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Tap submit, ensure downtime validation fires
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Both Downtime Start and Downtime End are required when downtime is enabled.'), findsOneWidget);
  });
}
