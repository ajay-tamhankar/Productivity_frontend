import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/live_timer_provider.dart';

/// Displays the elapsed time since [startTime] as `mm:ss` (or `hh:mm:ss`),
/// updating every second. Always derived from server time.
class LiveTimerText extends ConsumerWidget {
  final DateTime startTime;
  final TextStyle? style;
  final TextAlign? textAlign;

  const LiveTimerText({
    super.key,
    required this.startTime,
    this.style,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tick = ref.watch(liveTimerProvider(startTime));
    final duration = tick.asData?.value ??
        DateTime.now().toUtc().difference(startTime.toUtc());
    final text = formatLiveDuration(duration);

    // Default style uses a monospace family so digits don't dance.
    final defaultStyle = TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w700,
      fontSize: 16,
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Text(
      text,
      style: defaultStyle.merge(style),
      textAlign: textAlign,
    );
  }
}
