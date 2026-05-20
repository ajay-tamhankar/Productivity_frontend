import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/dpl_theme.dart';

/// App-bar refresh button with built-in busy feedback.
///
/// Tapping the button:
///   1. Fires a light haptic so the press is felt.
///   2. Starts a continuous spin animation on the refresh glyph.
///   3. Awaits the [onRefresh] future. While the future is pending
///      the icon morphs into a small spinner so the user can see
///      something is happening even on slow networks.
///   4. Settles back to the static glyph when the future completes.
///   5. Suppresses re-taps while a refresh is in flight.
///
/// Pass [onRefresh] as a function that returns a [Future]. Anything
/// awaitable works — wrap a sync invalidate in `Future.value(...)` or
/// (preferred) `await ref.read(provider.future)` after invalidating.
class DplRefreshIconButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final String tooltip;
  final Color? iconColor;
  final double size;

  const DplRefreshIconButton({
    super.key,
    required this.onRefresh,
    this.tooltip = 'Refresh',
    this.iconColor,
    this.size = 24,
  });

  @override
  State<DplRefreshIconButton> createState() => _DplRefreshIconButtonState();
}

class _DplRefreshIconButtonState extends State<DplRefreshIconButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    _spin.repeat();
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
      // Let the spinner ride out the current rotation so the morph
      // back to the glyph reads as deliberate rather than a flash.
      await _spin.animateTo(1, duration: const Duration(milliseconds: 250));
      _spin.stop();
      _spin.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.iconColor ?? DplColors.textPrimary;
    return IconButton(
      tooltip: widget.tooltip,
      onPressed: _busy ? null : _handleTap,
      icon: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (child, anim) =>
            ScaleTransition(scale: anim, child: child),
        child: _busy
            ? SizedBox(
                key: const ValueKey('spinner'),
                width: widget.size - 4,
                height: widget.size - 4,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              )
            : RotationTransition(
                key: const ValueKey('icon'),
                turns: _spin,
                child: Icon(Icons.refresh, color: color, size: widget.size),
              ),
      ),
    );
  }
}
