import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dpl_organization_provider.dart';
import 'dpl_user_menu.dart';
import 'vistar_logo.dart';

/// Polished, branded AppBar used by every DPL screen.
///
/// Layout (left → right):
///   * Leading — back arrow when the route can pop, otherwise the
///     Vistar wordmark logo.
///   * Title — bold display + optional [subtitle] widget below (e.g. a
///     "Live • updated 12s ago" indicator).
///   * Actions — caller-supplied widgets followed by [DplUserMenu]
///     (when [showProfile] is true).
///
/// Visual identity:
///   * White surface, no Material elevation.
///   * Brand-purple accent strip at the very top (the Vistar swoosh:
///     magenta → orange → yellow). This is the recognizable "Vistar
///     bar" across every screen.
///   * 1px neutral divider at the bottom.
class DplAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String title;
  final Widget? subtitle;
  final List<Widget> actions;
  final bool showProfile;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

  const DplAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.showProfile = true,
    this.leading,
    this.bottom,
  });

  // Brand tokens — kept inline so this widget has no design-system
  // import beyond VistarLogo / DplUserMenu.
  static const _accentMagenta = Color(0xFFA4257A);
  static const _accentOrange = Color(0xFFE54B2A);
  static const _accentYellow = Color(0xFFF5A623);
  static const _surface = Color(0xFFFFFFFF);
  static const _divider = Color(0xFFE5E7EB);
  static const _textPrimary = Color(0xFF111827);
  static const _textMuted = Color(0xFF6B7280);

  static const double _baseHeight = 72;
  static const double _accentStripHeight = 3;
  static const double _subtitleHeight = 18;

  double get _coreHeight =>
      _accentStripHeight + _baseHeight + (subtitle != null ? _subtitleHeight : 0);

  @override
  Size get preferredSize => Size.fromHeight(
        _coreHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPop = Navigator.of(context).canPop();
    final isPhone = MediaQuery.of(context).size.width < 600;
    final org = ref.watch(dplActiveOrganizationProvider);

    // Leading slot has two flavors:
    //   * Back arrow — fixed 56dp slot so titles align consistently
    //     across screens that can/can't pop.
    //   * Vistar wordmark — sized to its natural aspect ratio with
    //     tight horizontal padding. No SizedBox reservation, so the
    //     title sits immediately to the right of the logo and we
    //     don't leak whitespace when the asset has transparent
    //     padding.
    final Widget leadingWidget;
    if (leading != null) {
      leadingWidget = leading!;
    } else if (canPop) {
      leadingWidget = SizedBox(
        width: 56,
        child: Center(
          child: IconButton(
            tooltip: 'Back',
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _textPrimary,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      );
    } else {
      leadingWidget = Padding(
        padding: EdgeInsets.fromLTRB(isPhone ? 12 : 16, 0, isPhone ? 6 : 10, 0),
        child: VistarLogo(
          height: isPhone ? 56 : 64,
          showWordmark: true,
        ),
      );
    }

    return Material(
      color: _surface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Brand accent strip — instant Vistar recognition.
            Container(
              height: _accentStripHeight,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [_accentMagenta, _accentOrange, _accentYellow],
                ),
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: _divider, width: 1),
                ),
              ),
              height: _baseHeight + (subtitle != null ? _subtitleHeight : 0),
              child: Row(
                children: [
                  leadingWidget,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: TextStyle(
                                  color: _textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: isPhone ? 15 : 17,
                                  height: 1.15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (org != null) ...[
                              const SizedBox(width: 8),
                              _OrgPill(label: org.displayLabel, isPhone: isPhone),
                            ],
                          ],
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: DefaultTextStyle(
                              style: const TextStyle(
                                color: _textMuted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              child: subtitle!,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ...actions,
                  if (showProfile) const DplUserMenu(),
                ],
              ),
            ),
            ?bottom,
          ],
        ),
      ),
    );
  }
}

/// Compact tenant chip rendered next to the AppBar title when the
/// logged-in user has an active organization. Single visual cue that
/// makes it obvious which org's data the screen is showing — important
/// once more than one tenant is provisioned server-side.
class _OrgPill extends StatelessWidget {
  final String label;
  final bool isPhone;

  const _OrgPill({required this.label, required this.isPhone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 7 : 9,
        vertical: isPhone ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD8BFE9)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.business_rounded,
            size: 11,
            color: Color(0xFF4A1163),
          ),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isPhone ? 110 : 200),
            child: Text(
              label,
              style: TextStyle(
                color: const Color(0xFF4A1163),
                fontWeight: FontWeight.w700,
                fontSize: isPhone ? 10.5 : 11.5,
                height: 1.0,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
