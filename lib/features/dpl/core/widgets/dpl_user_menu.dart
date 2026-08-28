import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/auth_provider.dart';
import '../../../auth/change_password_dialog.dart';
import '../dpl_organization_provider.dart';

/// Shared profile button + popup used in every DPL AppBar.
///
/// Renders a circular avatar with the user's initial as the trigger.
/// Tapping opens a polished card with a gradient header (avatar, name,
/// role pill) followed by the action rows (Change Password, Logout).
///
/// Drop into any AppBar via `actions: [const DplUserMenu()]`.
class DplUserMenu extends ConsumerWidget {
  const DplUserMenu({super.key});

  // Brand colors — sourced from DplColors to stay in sync with the
  // wider design system (Vistar purple swoosh + warm accents).
  static const _primary = Color(0xFF6B1F8C);
  static const _primaryDark = Color(0xFF4A1163);
  static const _primaryTint = Color(0xFFF3E8F9);
  static const _danger = Color(0xFFDC2626);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);
  static const _divider = Color(0xFFE5E7EB);
  static const _surface = Colors.white;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).asData?.value;
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name
        : (user?.username ?? 'User');
    final initial = name.isEmpty ? 'U' : name.trim()[0].toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Tooltip(
        message: name,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _open(context, ref),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_primary, _primaryDark],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final user = ref.read(authControllerProvider).asData?.value;
    final name = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name
        : (user?.username ?? 'User');
    final roleLabel = AppConstants.roleLabel(user?.role ?? '');
    final email = user?.username ?? '';
    final orgLabel =
        ref.read(dplActiveOrganizationProvider)?.displayLabel ?? '';

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final button = context.findRenderObject() as RenderBox;
    final topRight = button.localToGlobal(
      button.size.topRight(Offset.zero),
      ancestor: overlay,
    );

    final action = await showMenu<_Action>(
      context: context,
      position: RelativeRect.fromLTRB(
        topRight.dx - 280,
        topRight.dy + 8,
        16,
        0,
      ),
      elevation: 12,
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 280),
      items: [
        PopupMenuItem<_Action>(
          enabled: false,
          padding: EdgeInsets.zero,
          height: orgLabel.isEmpty ? 96 : 112,
          child: _Header(
            name: name,
            role: roleLabel,
            email: email,
            org: orgLabel,
          ),
        ),
        const PopupMenuItem<_Action>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, color: _divider),
        ),
        PopupMenuItem<_Action>(
          value: _Action.changePassword,
          padding: EdgeInsets.zero,
          child: const _MenuRow(
            icon: Icons.lock_reset_outlined,
            label: 'Change Password',
            tint: _primaryTint,
            iconColor: _primary,
          ),
        ),
        const PopupMenuItem<_Action>(
          enabled: false,
          height: 1,
          padding: EdgeInsets.zero,
          child: Divider(height: 1, color: _divider),
        ),
        PopupMenuItem<_Action>(
          value: _Action.logout,
          padding: EdgeInsets.zero,
          child: const _MenuRow(
            icon: Icons.logout_rounded,
            label: 'Logout',
            tint: Color(0xFFFEECEC),
            iconColor: _danger,
            labelColor: _danger,
          ),
        ),
      ],
    );

    if (action == null || !context.mounted) return;

    switch (action) {
      case _Action.changePassword:
        await showChangePasswordDialog(context, ref);
        break;
      case _Action.logout:
        final confirmed = await _confirmLogout(context);
        if (confirmed != true || !context.mounted) return;
        await ref.read(authControllerProvider.notifier).logout();
        break;
    }
  }

  Future<bool?> _confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
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
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

enum _Action { changePassword, logout }

class _Header extends StatelessWidget {
  final String name;
  final String role;
  final String email;
  final String org;

  const _Header({
    required this.name,
    required this.role,
    required this.email,
    this.org = '',
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isEmpty ? 'U' : name.trim()[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7ECFC), Color(0xFFEED7F7)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [DplUserMenu._primary, DplUserMenu._primaryDark],
              ),
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: DplUserMenu._textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: DplUserMenu._primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    role.isEmpty ? 'Member' : role,
                    style: const TextStyle(
                      color: DplUserMenu._primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (org.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.business_rounded,
                        size: 11,
                        color: DplUserMenu._textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          org,
                          style: const TextStyle(
                            color: DplUserMenu._textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            height: 1.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final Color iconColor;
  final Color? labelColor;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.tint,
    required this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor ?? DplUserMenu._textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: DplUserMenu._textMuted,
          ),
        ],
      ),
    );
  }
}
