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

  testWidgets('ProductionEntryScreen one-step flow validation', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(MockApiClient())],
        child: const MaterialApp(home: ProductionEntryScreen()),
      ),
    );

    await tester.pumpAndSettle();

    // Verify single-step UI: both Start Time and End Time visible at once,
    // and quantity fields are visible without needing to press Start Shift.
    expect(find.text('Log Production Shift'), findsOneWidget);
    expect(find.text('Start Time *'), findsOneWidget);
    expect(find.text('End Time *'), findsOneWidget);
    expect(find.text('Actual Quantity *'), findsOneWidget);
    expect(find.text('Log Shift & Submit'), findsOneWidget);

    // The phase-1 Start Shift button should NOT exist.
    expect(find.text('Start Shift'), findsNothing);

    // Tap submit without filling anything to trigger validation.
    final submitButton = find.text('Log Shift & Submit');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Machine is required.'), findsOneWidget);
    expect(find.text('Item is required.'), findsOneWidget);
    expect(find.text('Actual Quantity is required.'), findsWidgets);

    // Add an operator name row and verify per-row validation triggers.
    final addOperatorButton = find.text('Add Operator');
    await tester.ensureVisible(addOperatorButton);
    await tester.tap(addOperatorButton);
    await tester.pumpAndSettle();

    expect(find.text('Operator 1 *'), findsOneWidget);

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Operator name cannot be empty.'), findsOneWidget);

    // Open the rejection details dialog from the same screen (no phase gate).
    final detailsButton = find.text('Rejection Details');
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(find.text('Forging Defects'), findsOneWidget);
    expect(find.text('Rolling Defects'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsNothing);

    // Toggling the downtime switch should reveal both downtime pickers in
    // the same one-step form (no phase navigation required).
    final switchFinder = find.widgetWithText(
      SwitchListTile,
      'Add Machine Downtime',
    );
    await tester.ensureVisible(switchFinder);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(find.text('Downtime Start *'), findsOneWidget);
    expect(find.text('Downtime End *'), findsOneWidget);
  });
}
