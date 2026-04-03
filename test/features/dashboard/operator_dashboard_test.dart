import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:productivity_tracker/features/dashboard/operator_dashboard_screen.dart';

import 'package:productivity_tracker/data/api_services/api_client.dart';
import '../../helpers/mock_api_client.dart';

void main() {
  testWidgets('OperatorDashboardScreen displays recent entries and navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(MockApiClient()),
        ],
        child: const MaterialApp(
          home: OperatorDashboardScreen(),
        ),
      ),
    );

    // Initial load - wait for API
    await tester.pumpAndSettle();

    expect(find.text('Operator Dashboard'), findsWidgets);
    expect(find.text('Your Recent Entries'), findsOneWidget);
    
    // Check for mock items
    expect(find.textContaining('ITEM-100'), findsOneWidget);
    
    // Check for FAB
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('New Entry'), findsOneWidget);

    // Verify Bottom Navigation Bar exists
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Navigate to settings tab
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();

    // Verify settings screen is displayed
    expect(find.text('Settings'), findsWidgets);
  });
}
