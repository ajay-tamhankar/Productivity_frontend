import 'package:flutter/material.dart';

import '../design/dpl_theme.dart';

/// 8dp tall, fully rounded progress bar.
///
/// [value] is clamped to [0, 1]. Pass [color] for a solid fill, or
/// [useGradient]=true to use the brand ribbon (reserved for hero
/// cards). Animates fills over 300ms ease-out.
class DplProgressBar extends StatelessWidget {
  final double value;
  final Color? color;
  final bool useGradient;
  final double height;

  const DplProgressBar({
    super.key,
    required this.value,
    this.color,
    this.useGradient = false,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final radius = BorderRadius.circular(height);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: DplColors.divider,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: constraints.maxWidth * v,
                  height: height,
                  decoration: BoxDecoration(
                    color: useGradient ? null : (color ?? DplColors.primary),
                    gradient: useGradient ? DplColors.brandGradient : null,
                    borderRadius: radius,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
