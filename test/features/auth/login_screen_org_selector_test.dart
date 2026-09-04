import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/features/auth/login_screen.dart';
import 'package:productivity_tracker/features/dpl/core/dpl_organization_provider.dart';

/// The org selector renders loading/error/empty states inline, inside an
/// InputDecorator. The error row has to survive a narrow phone width without
/// overflowing, so the retry affordance stays reachable.
void main() {
  Future<void> pumpLogin(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dplOrganizationListProvider.overrideWith(
            (ref) async => throw Exception('offline'),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('org selector error state fits a narrow phone width', (
    tester,
  ) async {
    await pumpLogin(tester, size: const Size(360, 800));

    expect(find.text('Could not load organizations.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // A RenderFlex overflow surfaces here as a caught layout exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets('org selector error state also fits a tablet width', (
    tester,
  ) async {
    await pumpLogin(tester, size: const Size(1000, 900));

    expect(find.text('Could not load organizations.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
