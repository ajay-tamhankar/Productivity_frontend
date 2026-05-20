import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/widgets/shimmer_skeleton.dart';

/// Big primary action button used throughout the supervisor flow.
///
/// - 64dp tall by default (glove-friendly)
/// - Triggers heavy haptic feedback on tap
/// - Disables itself + shows shimmer dots while [isBusy]
class StartStopButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isBusy;
  final double height;

  const StartStopButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.isBusy = false,
    this.height = 64,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton.icon(
        onPressed: (isBusy || onPressed == null)
            ? null
            : () {
                HapticFeedback.heavyImpact();
                onPressed!();
              },
        icon: isBusy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: Center(
                  child: ShimmerButtonDots(size: 7, spacing: 3.5),
                ),
              )
            : Icon(icon, size: 26),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 17,
            letterSpacing: 0.3,
          ),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
