import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/auth_provider.dart';
import '../../../auth/change_password_dialog.dart';
import '../design/dpl_role.dart';
import '../design/dpl_theme.dart';
import 'dpl_buttons.dart';
import 'dpl_refresh_icon_button.dart';
import 'vistar_logo.dart';

/// Unified app bar used by every DPL screen.
///
/// Layout (left → right):
///   * Leading — back arrow when the route can pop, otherwise the
///     Vistar mark (28dp).
///   * Title block — [title] in h2 style, optional [subtitle] in
///     caption below.
///   * Actions — optional refresh icon (shows a spinner while
///     [refreshing]), profile menu (always shown when [showProfile]).
///
/// Visuals: white background, 1px bottom divider, no Material
/// elevation. 56dp tall by default, 72dp when [subtitle] is set.
class DplAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;

  /// Async refresh action. The icon morphs to a spinner while the
  /// future is in flight so the user knows the tap registered.
  final Future<void> Function()? onRefresh;

  final bool showProfile;
  final List<Widget> extraActions;

  /// Force the leading element. When null, automatically picks back
  /// arrow (if `Navigator.canPop`) or the Vistar mark.
  final Widget? leading;

  const DplAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onRefresh,
    this.showProfile = true,
    this.extraActions = const [],
    this.leading,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(subtitle == null ? 56 : 72);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.of(context).canPop();

    final leadingWidget = leading ??
        (canPop
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back_rounded,
                    color: DplColors.textPrimary),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : Padding(
                padding: const EdgeInsets.only(left: DplSpacing.md),
                child: Center(
                  child: VistarLogo(height: 28),
                ),
              ));

    return Material(
      color: DplColors.cardBg,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: DplColors.divider, width: 1),
            ),
          ),
          height: preferredSize.height,
          child: Row(
            children: [
              SizedBox(width: 56, child: Center(child: leadingWidget)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: DplText.h2().copyWith(fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: DplText.caption(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              ...extraActions,
              if (onRefresh != null)
                DplRefreshIconButton(onRefresh: onRefresh!),
              if (showProfile)
                Padding(
                  padding: const EdgeInsets.only(right: DplSpacing.md),
                  child: _ProfileMenu(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileMenu extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value;
    final name = user?.name ?? 'User';
    final initial = name.isEmpty ? 'U' : name[0].toUpperCase();
    final roleLabel = DplRole.labelFor(user?.role);

    return PopupMenuButton<_MenuAction>(
      tooltip: 'Account',
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DplRadius.md),
      ),
      onSelected: (action) async {
        switch (action) {
          case _MenuAction.profile:
            // Navigate to supervisor profile tab if available. Manager
            // doesn't have a dedicated screen yet — silently no-op.
            if (DplRole.isSupervisor(user?.role)) {
              context.go('/dpl/supervisor');
            }
            break;
          case _MenuAction.changePassword:
            if (context.mounted) {
              showChangePasswordDialog(context, ref);
            }
            break;
          case _MenuAction.logout:
            if (!context.mounted) return;
            final confirm = await _confirmLogout(context);
            if (confirm != true) return;
            await ref.read(authControllerProvider.notifier).logout();
            break;
          case _MenuAction.header:
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          enabled: false,
          value: _MenuAction.header,
          height: 56,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                style: DplText.body()
                    .copyWith(color: DplColors.textPrimary, fontWeight: FontWeight.w800),
              ),
              Text(roleLabel, style: DplText.caption()),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.profile,
          child: Row(
            children: const [
              Icon(Icons.person_outline, color: DplColors.textPrimary),
              SizedBox(width: 10),
              Text('Profile'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _MenuAction.changePassword,
          child: Row(
            children: const [
              Icon(Icons.lock_reset, color: DplColors.textPrimary),
              SizedBox(width: 10),
              Text('Change Password'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: _MenuAction.logout,
          child: Row(
            children: const [
              Icon(Icons.logout, color: DplColors.error),
              SizedBox(width: 10),
              Text('Logout',
                  style: TextStyle(
                    color: DplColors.error,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ],
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: DplColors.primaryTint,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: DplText.bodyLg().copyWith(
            color: DplColors.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DplRadius.lg),
        ),
        title: const Text('Log out?'),
        content: const Text(
          'You will need to sign in again to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          SizedBox(
            width: 120,
            child: DplDangerButton(
              label: 'Log out',
              height: 44,
              fullWidth: true,
              onPressed: () => Navigator.pop(dialogContext, true),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MenuAction { header, profile, changePassword, logout }
