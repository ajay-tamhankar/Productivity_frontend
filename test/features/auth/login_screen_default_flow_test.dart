import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/auth/login_screen.dart';
import 'package:productivity_tracker/features/dpl/core/dpl_organization_provider.dart';
import 'package:productivity_tracker/features/dpl/models/dpl_organization.dart';

/// The landing flow is a product decision, not an implementation detail —
/// these lock it in so a refactor can't quietly flip it back.
void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    List<DplOrganization> orgs = const [],
  }) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Keep the org selector off the network.
          dplOrganizationListProvider.overrideWith((ref) async => orgs),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('lands on Vistar Pulse, not the classic flow', (tester) async {
    await pumpLogin(tester);

    expect(find.text('Vistar Pulse'), findsWidgets);
    expect(find.text('Sign in to Vistar Pulse'), findsOneWidget);
    expect(find.text('Sign in to Productivity'), findsNothing);
  });

  testWidgets('shows the Pulse fields on first paint', (tester) async {
    await pumpLogin(tester);

    // Email (not Username) and the org selector are Pulse-only.
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Username'), findsNothing);
    expect(find.text('Organization'), findsWidgets);
  });

  testWidgets('classic Productivity flow is still one tap away', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.tap(find.text('Productivity').last);
    await tester.pumpAndSettle();

    expect(find.text('Sign in to Productivity'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Organization'), findsNothing);
  });
}
