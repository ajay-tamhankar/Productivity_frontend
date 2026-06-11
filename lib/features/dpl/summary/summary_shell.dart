import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../auth/auth_provider.dart';
import '../core/design/dpl_theme.dart';
import '../core/widgets/dpl_app_bar.dart';
import '../core/widgets/dpl_bottom_nav.dart';
import '../core/widgets/dpl_refresh_icon_button.dart';
import 'providers/dispatch_slips_provider.dart';
import 'providers/production_summary_provider.dart';
import 'providers/summary_tab_provider.dart';
import 'screens/dispatch_slip_verifier_screen.dart';
import 'screens/dispatch_slips_inbox_screen.dart';
import 'screens/production_summary_screen.dart';

/// Two-tab shell for the Dispatch / QA / PDI roles.
///
/// Tab 0 — Production Summary (the running aggregate of total actual qty
/// per machine + part, with the Request Dispatch Slip CTA for Dispatch).
///
/// Tab 1 — Dispatch Slips inbox/list with role-aware status defaults:
///   * QA lands on the "Pending QA" filter
///   * PDI lands on the "Pending PDI" filter
///   * Dispatch sees their own slips across every status
///
/// The bottom-nav badge on the Slips tab shows the live pending count
/// for the active role's queue, sourced from the slips list endpoint's
/// `totals` block so it stays accurate without an extra round-trip.
class DplSummaryShell extends ConsumerWidget {
  const DplSummaryShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value;
    final role = user?.role ?? '';
    final tabIndex = ref.watch(dplSummaryTabProvider).clamp(0, 1);

    final summaryTitle = _summaryTitleForRole(role);
    final slipsTitle = _slipsTitleForRole(role);

    final pages = const <Widget>[
      ProductionSummaryScreen(showAppBar: false),
      DispatchSlipsInboxScreen(showAppBar: false),
    ];

    final titles = [summaryTitle, slipsTitle];

    // Live pending count for whichever queue this role primarily owns —
    // QA → pending_qa, PDI → pending_pdi, Dispatch → pending_qa + pending_pdi
    // (everything not yet approved or terminal). Manager uses the QA
    // count as a generic "needs attention" signal.
    final pendingCount = _pendingCountForRole(ref, role);

    return Scaffold(
      backgroundColor: DplColors.pageBg,
      appBar: DplAppBar(
        title: titles[tabIndex],
        actions: [
          IconButton(
            tooltip: 'Verify slip QR',
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const DispatchSlipVerifierScreen(),
              ),
            ),
          ),
          DplRefreshIconButton(
            onRefresh: () async {
              if (tabIndex == 0) {
                ref.invalidate(dplProductionSummaryProvider);
                try {
                  await ref.read(dplProductionSummaryProvider.future);
                } catch (_) {}
              } else {
                ref.invalidate(dplDispatchSlipsProvider);
                try {
                  await ref.read(dplDispatchSlipsProvider.future);
                } catch (_) {}
              }
            },
          ),
        ],
      ),
      body: IndexedStack(index: tabIndex, children: pages),
      bottomNavigationBar: DplBottomNav(
        currentIndex: tabIndex,
        items: [
          const DplNavItem(
            icon: Icons.summarize_outlined,
            selectedIcon: Icons.summarize,
            label: 'Production',
          ),
          DplNavItem(
            icon: pendingCount > 0
                ? Icons.notifications_active_outlined
                : Icons.receipt_long_outlined,
            selectedIcon: Icons.receipt_long,
            label: pendingCount > 0
                ? 'Slips ($pendingCount)'
                : 'Slips',
          ),
        ],
        onTap: (i) {
          ref.read(dplSummaryTabProvider.notifier).set(i);
          // Re-tapping the active tab refreshes the live data, same
          // pattern the manager shell uses.
          if (i == 0) {
            ref.invalidate(dplProductionSummaryProvider);
          } else {
            ref.invalidate(dplDispatchSlipsProvider);
          }
        },
      ),
    );
  }

  /// Title for the Production Summary tab, prefixed by role so the user
  /// always knows which "lens" they're in.
  String _summaryTitleForRole(String role) {
    if (AppConstants.isDplDispatchRole(role)) {
      return 'Dispatch — Production Summary';
    }
    if (AppConstants.isDplQaRole(role)) {
      return 'QA — Production Summary';
    }
    if (AppConstants.isDplPdiRole(role)) {
      return 'PDI — Production Summary';
    }
    return 'Production Summary';
  }

  String _slipsTitleForRole(String role) {
    if (AppConstants.isDplDispatchRole(role)) return 'My Dispatch Slips';
    if (AppConstants.isDplQaRole(role)) return 'QA — Dispatch Slips';
    if (AppConstants.isDplPdiRole(role)) return 'PDI — Dispatch Slips';
    return 'Dispatch Slips';
  }

  /// Count to show on the Slips nav-bar badge. Reads from the slips
  /// provider's `totals` block (which ignores the active filter), so the
  /// badge reflects the role's queue depth even when the user is
  /// filtered to a different status.
  int _pendingCountForRole(WidgetRef ref, String role) {
    final totals = ref
            .watch(dplDispatchSlipsProvider)
            .asData
            ?.value
            .data
            ?.totals;
    if (totals == null) return 0;
    if (AppConstants.isDplQaRole(role)) return totals.pendingQa;
    if (AppConstants.isDplPdiRole(role)) return totals.pendingPdi;
    if (AppConstants.isDplDispatchRole(role)) {
      // Dispatch cares about both queues since they're the requester.
      return totals.pendingQa + totals.pendingPdi;
    }
    // Manager fallback.
    return totals.pendingQa + totals.pendingPdi;
  }
}
