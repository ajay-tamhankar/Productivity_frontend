import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/dpl_manager_tab_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/masters_hub_screen.dart';
import 'screens/plan_list_screen.dart';
import 'screens/reports_screen.dart';
import 'widgets/dpl_manager_footer.dart';

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
      bottomNavigationBar: const DplManagerFooter(popToShellOnTap: false),
    );
  }
}

class _EmbeddedPlanList extends StatelessWidget {
  const _EmbeddedPlanList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Production Plans')),
      body: const DplPlanListScreen(embedded: true),
    );
  }
}

