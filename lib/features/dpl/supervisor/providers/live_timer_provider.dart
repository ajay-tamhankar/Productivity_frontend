import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ticking duration provider, **family-keyed by the server-issued
/// `startTime`** so multiple timers can run side-by-side (one for the
/// item, one for the active downtime) without interfering.
///
/// The duration is always derived from `DateTime.now()` minus the server
/// start time — we never accumulate a counter locally. That means even
/// after backgrounding or hot-reload, the displayed elapsed time stays
/// correct as soon as the widget rebuilds.
final liveTimerProvider = StreamProvider.autoDispose
    .family<Duration, DateTime>((ref, startTime) async* {
  // Initial value immediately so the widget doesn't briefly show 00:00.
  yield _elapsed(startTime);

  final ticker = Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
  await for (final _ in ticker) {
    yield _elapsed(startTime);
  }
});

Duration _elapsed(DateTime startTime) {
  // Normalise to UTC so device timezone never causes drift.
  return DateTime.now().toUtc().difference(startTime.toUtc());
}

/// Formats a [Duration] as `hh:mm:ss` (if >= 1 hour) or `mm:ss`.
String formatLiveDuration(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (h > 0) return '${h.toString().padLeft(2, '0')}:$m:$s';
  return '$m:$s';
}
