import '../core/dpl_constants.dart';
import 'dpl_dispatch_slip.dart';

/// Whether a trip is dispatch-complete, and if not, what is holding it up.
///
/// This mirrors `tripDispatchReadiness()` in the backend's
/// `tripJourneyService.js` **exactly**, and the two must stay in step. The
/// rule is: every non-`rejected` slip on the trip must be `dispatched`, and
/// there must be at least one such slip.
///
/// Why it matters: `gateOut` refuses to let a truck leave unless the trip is
/// dispatch-complete, and `assignDriver` now refuses for the same reason. If
/// the UI offered "Assign Driver" on a half-dispatched trip, the assignment
/// would either be rejected (best case) or — before the backend guard existed
/// — succeed and strand the driver: booked against a trip that can never
/// gate out, and therefore unavailable for any other trip.
///
/// The backend is the authority; this exists so the UI can disable the action
/// and explain why *before* the dispatcher taps it.
class TripDispatchReadiness {
  /// True when the trip can accept a driver and later gate out.
  final bool ready;

  /// Non-rejected slips on the trip.
  final int liveCount;

  /// How many of [liveCount] have reached `dispatched`.
  final int dispatchedCount;

  /// Outstanding slip statuses → how many slips sit at each. Insertion
  /// order follows [DplDispatchSlipStatus.all] so the reason string reads
  /// in pipeline order rather than whatever order the slips arrived in.
  final Map<String, int> outstanding;

  const TripDispatchReadiness({
    required this.ready,
    required this.liveCount,
    required this.dispatchedCount,
    required this.outstanding,
  });

  factory TripDispatchReadiness.of(Iterable<DplDispatchSlip> slips) {
    final live = slips
        .where((s) => s.status != DplDispatchSlipStatus.rejected)
        .toList(growable: false);
    final pending = live
        .where((s) => s.status != DplDispatchSlipStatus.dispatched)
        .toList(growable: false);

    // Count first, then emit in pipeline order.
    final counts = <String, int>{};
    for (final s in pending) {
      counts[s.status] = (counts[s.status] ?? 0) + 1;
    }
    final ordered = <String, int>{};
    for (final status in DplDispatchSlipStatus.all) {
      final n = counts.remove(status);
      if (n != null) ordered[status] = n;
    }
    // Anything the constant list doesn't know about still gets reported
    // rather than silently vanishing from the count.
    ordered.addAll(counts);

    return TripDispatchReadiness(
      ready: live.isNotEmpty && pending.isEmpty,
      liveCount: live.length,
      dispatchedCount: live.length - pending.length,
      outstanding: ordered,
    );
  }

  int get pendingCount => liveCount - dispatchedCount;

  /// Short label for the disabled chip on the trip card. Kept tight — the
  /// full explanation lives in [blockReason], shown on tap.
  String get shortReason {
    if (liveCount == 0) return 'No slips yet';
    return '$pendingCount of $liveCount slips pending';
  }

  /// Full, dispatcher-facing explanation. Deliberately worded the same way
  /// as the backend's refusal so the two never appear to disagree.
  String get blockReason {
    if (liveCount == 0) {
      return 'This trip has no active slips yet. Create and dispatch its '
          'slips before assigning a driver.';
    }
    final detail = outstanding.entries
        .map((e) => '${e.value} ${DplDispatchSlipStatus.label(e.key)}')
        .join(', ');
    return 'Only $dispatchedCount of $liveCount slips are dispatched '
        '($detail still open).\n\nA driver can only be assigned once every '
        'slip on the trip is dispatched — otherwise the truck can never be '
        'gate-outed, and the driver would be locked to a trip that cannot '
        'move.';
  }
}
