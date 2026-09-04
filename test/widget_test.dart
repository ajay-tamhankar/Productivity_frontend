// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:productivity_tracker/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Mock shared prefs
    SharedPreferences.setMockInitialValues({});

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(child: ProductionMonitoringApp()),
    );
    await tester.pumpAndSettle(); // Wait for Riverpod async initialization and GoRouter

    // Since it's clean shared prefs, we expect to be at the Login Screen.
    // It defaults to the Vistar Pulse flow.
    expect(find.text('Vistar Pulse'), findsWidgets);
    expect(find.text('Sign in to Vistar Pulse'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
