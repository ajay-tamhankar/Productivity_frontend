import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/dpl_bottom_nav.dart';
import '../providers/dpl_manager_tab_provider.dart';

/// Bottom nav for every DPL Manager screen.
///
/// Visual implementation lives in [DplBottomNav]; this widget keeps
/// the original public name + shell-pop behaviour so nested screens
/// don't need updates.
class DplManagerFooter extends ConsumerWidget {
  /// When true, taps switch tab AND pop back to the shell. Set false
  /// on the shell itself.
  final bool popToShellOnTap;

  /// Optional widget rendered ABOVE the nav bar (e.g. "Lock Plan").
  final Widget? aboveNav;

  const DplManagerFooter({
    super.key,
    this.popToShellOnTap = true,
    this.aboveNav,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(dplManagerTabProvider);

    final nav = DplBottomNav(
      currentIndex: index,
      items: dplManagerNavItems,
      onTap: (i) {
        ref.read(dplManagerTabProvider.notifier).set(i);
        if (popToShellOnTap) {
          while (context.canPop()) {
            context.pop();
          }
          if (GoRouterState.of(context).matchedLocation != '/dpl/manager') {
            context.go('/dpl/manager');
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
