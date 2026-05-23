import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/widgets/dpl_app_bar.dart';
import '../core/widgets/dpl_bottom_nav.dart';
import '../core/widgets/dpl_refresh_icon_button.dart';
import 'providers/dpl_dashboard_provider.dart';
import 'providers/dpl_manager_tab_provider.dart';
import 'providers/dpl_plan_list_provider.dart';
import 'providers/dpl_reports_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/masters_hub_screen.dart';
import 'screens/plan_list_screen.dart';
import 'screens/reports_screen.dart';

/// Bottom-nav container for the DPL Manager experience.
/// Dashboard / Plans / Reports / Settings.
///
/// The active tab is held in `dplManagerTabProvider` so the persistent
/// footer mounted on nested detail screens can switch tabs without
/// losing state.
class DplManagerShell extends ConsumerWidget {
  const DplManagerShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dplManagerTabProvider);

    const pages = [
      DplManagerDashboardScreen(),
      _EmbeddedPlanList(),
      DplReportsScreen(),
      DplMastersHubScreen(embedded: true),
    ];

    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      bottomNavigationBar: DplBottomNav(
        currentIndex: index,
        items: dplManagerNavItems,
        onTap: (i) {
          ref.read(dplManagerTabProvider.notifier).set(i);
          // Every tab tap (including re-tapping the active tab)
          // refreshes the destination's primary data so the manager
          // never sees stale numbers without a manual gesture.
          switch (i) {
            case 0:
              ref.invalidate(dplDashboardSummaryProvider);
              ref.invalidate(dplDashboardMtdProvider);
              break;
            case 1:
              ref.invalidate(dplPlanListProvider);
              break;
            case 2:
              ref.invalidate(dplPlanVsActualReportProvider);
              ref.invalidate(dplDowntimeReportProvider);
              break;
            case 3:
              // Settings is mostly navigation tiles — nothing live
              // to invalidate here.
              break;
          }
        },
      ),
    );
  }
}

class _EmbeddedPlanList extends ConsumerWidget {
  const _EmbeddedPlanList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: DplAppBar(
        title: 'Production Plans',
        actions: [
          DplRefreshIconButton(
            onRefresh: () async {
              ref.invalidate(dplPlanListProvider);
              try {
                await ref.read(dplPlanListProvider.future);
              } catch (_) {}
            },
          ),
        ],
      ),
      body: const DplPlanListScreen(embedded: true),
    );
  }
}
