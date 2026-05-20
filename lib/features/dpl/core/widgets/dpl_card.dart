import 'package:flutter/material.dart';

import '../design/dpl_theme.dart';

/// Base card surface used across DPL screens. White background, large
/// radius, soft 2-layer shadow, optional [accentColor] left border for
/// status indication, optional [onTap] for ripple.
class DplCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? accentColor;
  final VoidCallback? onTap;
  final double radius;

  const DplCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DplSpacing.lg),
    this.margin,
    this.accentColor,
    this.onTap,
    this.radius = DplRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    final accent = accentColor;
    final borderRadius = BorderRadius.circular(radius);

    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: borderRadius,
        boxShadow: DplShadows.card,
        border: accent != null
            ? Border(left: BorderSide(color: accent, width: 4))
            : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: surface,
    );

    final content = onTap == null
        ? clipped
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              child: clipped,
            ),
          );

    if (margin == null) return content;
    return Padding(padding: margin!, child: content);
  }
}
