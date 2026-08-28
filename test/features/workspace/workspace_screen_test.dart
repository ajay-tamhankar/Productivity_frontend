import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:productivity_tracker/core/constants/app_constants.dart';
import 'package:productivity_tracker/data/models/user_model.dart';
import 'package:productivity_tracker/features/auth/auth_provider.dart';
import 'package:productivity_tracker/features/workspace/data/vistar_app_catalog.dart';
import 'package:productivity_tracker/features/workspace/workspace_account.dart';
import 'package:productivity_tracker/features/workspace/workspace_screen.dart';

/// Stands in for the real controller so the screen renders without
/// shared-preferences or the network.
class _SignedInAsPortalUser extends AuthController {
  @override
  FutureOr<UserModel?> build() => UserModel(
    id: VistarWorkspaceAccount.userId,
    username: VistarWorkspaceAccount.username,
    name: VistarWorkspaceAccount.displayName,
    role: AppConstants.roleVistarWorkspace,
  );
}

/// A workspace user whose password the launcher cannot recover — the
/// state after a browser refresh on a non-portal account.
class _SignedInWithoutPassword extends AuthController {
  @override
  FutureOr<UserModel?> build() => UserModel(
    id: '99',
    username: 'someone.else@vistarlogitek.com',
    name: 'Someone Else',
    role: AppConstants.roleVistarWorkspace,
  );
}

void main() {
  Future<void> pumpLauncher(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedInAsPortalUser.new),
        ],
        child: const MaterialApp(home: WorkspaceScreen()),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders a tile for every app in the catalog', (tester) async {
    await pumpLauncher(tester, const Size(1400, 3000));

    for (final app in kVistarAppCatalog) {
      expect(
        find.text(app.name),
        findsOneWidget,
        reason: '${app.name} tile is missing',
      );
    }
    expect(find.text('${kVistarAppCatalog.length} apps'), findsOneWidget);
  });

  testWidgets('greets the signed-in user and shows their role', (tester) async {
    await pumpLauncher(tester, const Size(1400, 3000));

    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.text('Prashant'), findsOneWidget);
    expect(find.text('Vistar Workspace'), findsWidgets);
  });

  testWidgets('search narrows the grid and offers a way back', (tester) async {
    await pumpLauncher(tester, const Size(1400, 3000));

    await tester.enterText(find.byType(TextField), 'hire');
    await tester.pump();

    expect(find.text('Vistar Hire'), findsOneWidget);
    expect(find.text('KRA'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();

    expect(find.text('No apps match'), findsOneWidget);
    await tester.tap(find.text('Show all apps'));
    await tester.pump();
    expect(find.text('KRA'), findsOneWidget);
  });

  testWidgets('category chip filters to a single suite', (tester) async {
    await pumpLauncher(tester, const Size(1400, 3000));

    await tester.tap(find.byKey(const ValueKey('workspace-suite-Governance')));
    await tester.pump();

    expect(find.text('Audit Management'), findsOneWidget);
    expect(find.text('Note for Approval'), findsOneWidget);
    expect(find.text('VTMS'), findsNothing);
  });

  testWidgets('advertises one-click sign-in for the portal account', (
    tester,
  ) async {
    await pumpLauncher(tester, const Size(1400, 3000));

    expect(find.text('One-click sign-in on'), findsOneWidget);
    expect(find.textContaining('signs you in there'), findsOneWidget);
  });

  testWidgets('says so plainly when the password cannot be recovered', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(_SignedInWithoutPassword.new),
        ],
        child: const MaterialApp(home: WorkspaceScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('One-click sign-in off'), findsOneWidget);
    expect(find.textContaining('re-enable one-click sign-in'), findsOneWidget);
    // Tiles still work — they just land on the app's own login form.
    expect(find.text('KRA'), findsOneWidget);
  });

  testWidgets('lays out on a phone-width viewport without overflow', (
    tester,
  ) async {
    await pumpLauncher(tester, const Size(390, 4200));
    expect(tester.takeException(), isNull);
    expect(find.text('KRA'), findsOneWidget);
  });
}
