import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/dpl_bottom_nav.dart';
import '../providers/dpl_supervisor_tab_provider.dart';

/// Bottom nav for every DPL Supervisor screen. Visual implementation
/// lives in [DplBottomNav].
class DplSupervisorFooter extends ConsumerWidget {
  final bool popToShellOnTap;
  final Widget? aboveNav;

  const DplSupervisorFooter({
    super.key,
    this.popToShellOnTap = true,
    this.aboveNav,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dplSupervisorTabProvider);

    final nav = DplBottomNav(
      currentIndex: index,
      items: dplSupervisorNavItems,
      onTap: (i) {
        ref.read(dplSupervisorTabProvider.notifier).set(i);
        if (popToShellOnTap) {
          while (context.canPop()) {
            context.pop();
          }
          if (GoRouterState.of(context).matchedLocation !=
              '/dpl/supervisor') {
            context.go('/dpl/supervisor');
          }
        }
      },
    );

    if (aboveNav == null) return nav;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [aboveNav!, nav],
    );
  }
}
