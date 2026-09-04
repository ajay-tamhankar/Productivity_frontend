import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:productivity_tracker/features/dashboard/operator_dashboard_screen.dart';

import 'package:productivity_tracker/data/api_services/api_client.dart';
import '../../helpers/mock_api_client.dart';

void main() {
  Future<void> pumpDashboard(
    WidgetTester tester, {
    Size size = const Size(1000, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(MockApiClient())],
        child: const MaterialApp(home: OperatorDashboardScreen()),
      ),
    );
    // Initial load - wait for API
    await tester.pumpAndSettle();
  }

  testWidgets('OperatorDashboardScreen displays recent entries', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('Operator Dashboard'), findsWidgets);

    // The body is a lazy ListView, so the feed section is only built once it
    // scrolls into view - the stats and productivity cards come first.
    await tester.scrollUntilVisible(find.text('Recent Entries'), 300);
    await tester.pumpAndSettle();

    expect(find.text('Recent Entries'), findsOneWidget);

    // Check for mock items
    expect(find.textContaining('ITEM-100'), findsOneWidget);
  });

  testWidgets('OperatorDashboardScreen exposes the Log Shift action', (
    tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Log Shift'), findsOneWidget);
  });

  testWidgets('wide layout puts account actions directly in the app bar', (
    tester,
  ) async {
    await pumpDashboard(tester, size: const Size(1000, 800));

    expect(find.byTooltip('Refresh'), findsOneWidget);
    expect(find.byTooltip('Change Password'), findsOneWidget);
    expect(find.byTooltip('Logout'), findsOneWidget);

    // Navigation lives in the app bar now; there is no bottom navigation bar.
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('compact layout collapses account actions into a menu', (
    tester,
  ) async {
    // Below the 760px breakpoint the actions fold into a popup menu.
    await pumpDashboard(tester, size: const Size(700, 900));

    final menu = find.byWidgetPredicate((w) => w is PopupMenuButton);
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });
}
