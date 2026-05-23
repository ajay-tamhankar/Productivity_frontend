import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/auth_provider.dart';
import '../../../auth/change_password_dialog.dart';
import '../../core/widgets/dpl_app_bar.dart';
import '../providers/dpl_supervisor_tab_provider.dart';
import '../widgets/downtime_banner.dart';
import '../widgets/dpl_supervisor_footer.dart';
import '../widgets/shift_identity_guard.dart';
import 'shift_summary_screen.dart';
import 'supervisor_dashboard_screen.dart';

class SupervisorShell extends ConsumerWidget {
  const SupervisorShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dplSupervisorTabProvider);

    const pages = [
      SupervisorDashboardScreen(),
      ShiftSummaryScreen(),
      _SupervisorProfileTab(),
    ];

    return ShiftIdentityGuard(
      child: Scaffold(
        body: Column(
          children: [
            const DowntimeBanner(),
            Expanded(child: IndexedStack(index: index, children: pages)),
          ],
        ),
        bottomNavigationBar:
            const DplSupervisorFooter(popToShellOnTap: false),
      ),
    );
  }
}

class _SupervisorProfileTab extends ConsumerWidget {
  const _SupervisorProfileTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value;
    final name = user?.name ?? 'Supervisor';
    final username = user?.username ?? '';
    final role = user?.role ?? '';

    return Scaffold(
      appBar: const DplAppBar(title: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border.all(color: const Color(0xFFE2EAF6)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    name.isEmpty ? 'S' : name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                      if (username.isNotEmpty)
                        Text(
                          username,
                          style:
                              const TextStyle(color: Color(0xFF5D6A7A)),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF3FB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          role,
                          style: const TextStyle(
                            color: Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ListTile(
            leading: const Icon(Icons.lock_reset_outlined),
            title: const Text('Change Password'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2EAF6)),
            ),
            onTap: () => showChangePasswordDialog(context, ref),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.logout, color: Color(0xFFB3261E)),
            title: const Text(
              'Logout',
              style: TextStyle(color: Color(0xFFB3261E)),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFFFB4AA)),
            ),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
