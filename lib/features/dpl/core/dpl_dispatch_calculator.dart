/// Pure-Dart JIT buffer-replenishment calculator.
///
/// Given today's stock + production + consumption inputs, computes how
/// many NOS of each part should be dispatched to the customer to keep
/// the customer's buffer at its safe-stock target.
///
/// This is the math layer for the "Auto Dispatch Plan" feature. It has
/// **no dependencies on Flutter, Riverpod, or HTTP** — the calculator
/// is fully testable in isolation. The UI layer (Today's Dispatch Plan
/// screen) and the data layer (morning stock entry, plan provider)
/// both consume `DplDispatchCalculator.calculate(...)` and never touch
/// the formula directly.
///
/// ---
///
/// **The formula** (per part, per day)
///
/// ```
/// needed_at_tml   = max(0, buffer_target_at_tml − tml_opening_stock + customer_plan_today)
/// available_at_ga = ga_opening_stock + ga_production_today
/// dispatch_today  = min(needed_at_tml, available_at_ga)
/// shortage        = max(0, needed_at_tml − available_at_ga)
/// ```
///
/// Worked example from the Buffer Plan screenshot (`103D1`):
///
/// ```
/// S_tml = 10,  C_today = 25,  S_ga = 50,  P_today = 30,  buffer_target = 35
///
/// needed_at_tml   = max(0, 35 − 10 + 25) = 50
/// available_at_ga = 50 + 30 = 80
/// dispatch_today  = min(50, 80) = 50 NOS
/// shortage        = 0
///
/// projected_tml_closing = 10 − 25 + 50 = 35  (= buffer target ✓)
/// projected_ga_closing  = 50 + 30 − 50 = 30
/// ```
///
/// ---
///
/// **Trip-slot split**
///
/// Once we know `dispatch_today` and the trolley capacity, the
/// calculator distributes the load across the day's trip slots as
/// evenly as possible (a base qty per trip + 1 extra trolley going to
/// the earliest trips). This matches how the operations team allocates
/// trolleys on the manual Trip Plan sheet today — bigger loads go on
/// the morning runs to refill the customer's start-of-shift buffer.
///
/// ---
///
/// **Edge cases the calculator handles cleanly**
///
///   * Already-over-stocked customer → `dispatch_today = 0`
///   * Customer call-off is zero → still tops up to buffer if low
///   * GA can't fully cover → dispatch = what GA has, `shortage > 0`
///   * Buffer target is 0 (no safety stock policy) → dispatch = max(0, C_today − S_tml)
///   * Negative or missing inputs → treated as 0 (defensive)
library;

import 'dart:math' as math;

/// Inputs for one part on one day. All quantities are integer NOS.
class DispatchCalcInput {
  /// Internal part id — used by the UI to map back to the part row.
  final int partId;

  /// Customer-side part number, e.g. `549169500103D1`. Display only.
  final String customerPn;

  /// Short description code, e.g. `103D1`. Display only.
  final String description;

  /// Buffer target the customer wants to maintain at start of day
  /// (master data, configured once per part).
  final int bufferTargetAtTml;

  /// NOS per trolley. Drives trolley count + trip-slot split.
  /// Must be > 0; trolley count falls back to 1 if non-positive.
  final int trolleyCapacity;

  /// Customer's opening stock this morning (manager / dispatch
  /// enters this each day from the customer's stock call).
  final int tmlOpeningStock;

  /// Customer's planned production today — the qty they will
  /// consume of this part. Drives "how much do they need to end
  /// the day at buffer target".
  final int customerPlanToday;

  /// Our (GA) opening stock — pulled from yesterday's closing.
  /// Already tracked in `dpl_production_summary.available_for_dispatch_qty`.
  final int gaOpeningStock;

  /// Today's planned production at GA — pulled from the active DPL
  /// plan.
  final int gaProductionToday;

  /// Number of trip slots / day. Defaults to 6 (matches the Trip
  /// Plan Excel — 06:00, 07:30, 09:20, 12:00, 15:00, 18:00).
  final int tripsPerDay;

  const DispatchCalcInput({
    required this.partId,
    required this.customerPn,
    required this.description,
    required this.bufferTargetAtTml,
    required this.trolleyCapacity,
    required this.tmlOpeningStock,
    required this.customerPlanToday,
    required this.gaOpeningStock,
    required this.gaProductionToday,
    this.tripsPerDay = 6,
  });
}

/// Per-part result of running the calculator.
class DispatchCalcResult {
  final int partId;
  final String customerPn;
  final String description;

  /// Raw need to end the day at the customer's buffer target.
  /// `max(0, buffer_target − S_tml + C_today)`.
  final int neededAtTml;

  /// Total GA-side availability. `S_ga + P_today`.
  final int availableAtGa;

  /// Final dispatch qty. `min(needed_at_tml, available_at_ga)`.
  /// This is the number the UI shows + the Dispatch Slip carries.
  final int dispatchToday;

  /// Positive when GA can't fully cover the customer need.
  /// UI surfaces this as a warning so operations can push more
  /// production or pull from another plant.
  final int shortage;

  /// Total trolleys for today = `ceil(dispatch_today / trolley_capacity)`.
  /// Zero when nothing needs dispatching.
  final int totalTrolleys;

  /// Per-trip-slot qty split. Length == `tripsPerDay`. Front-loaded
  /// when the split doesn't divide evenly (extra trolleys go to the
  /// earlier slots).
  final List<int> tripQtySplit;

  /// Per-trip-slot trolley split. Same length as `tripQtySplit`.
  final List<int> tripTrolleySplit;

  /// Customer's projected closing stock at end of today.
  /// `S_tml − C_today + dispatch_today`. Should equal buffer target
  /// when GA has enough; less when there's a shortage.
  final int projectedTmlClosingStock;

  /// GA's projected closing stock at end of today.
  /// `S_ga + P_today − dispatch_today`. Stays at >=0 by construction.
  final int projectedGaClosingStock;

  const DispatchCalcResult({
    required this.partId,
    required this.customerPn,
    required this.description,
    required this.neededAtTml,
    required this.availableAtGa,
    required this.dispatchToday,
    required this.shortage,
    required this.totalTrolleys,
    required this.tripQtySplit,
    required this.tripTrolleySplit,
    required this.projectedTmlClosingStock,
    required this.projectedGaClosingStock,
  });

  /// True when GA can't fully cover today's customer need. UI shows
  /// a warning row when this is set.
  bool get hasShortage => shortage > 0;

  /// True when there's no dispatch action needed at all (customer is
  /// already at or above buffer target after today's consumption).
  bool get isQuiet => dispatchToday == 0;
}

/// Aggregate roll-up across every part — drives the "Today's Plan"
/// header card (total dispatch, total trolleys, shortage flag).
class DispatchCalcBatch {
  final DateTime planDate;
  final List<DispatchCalcResult> perPart;

  /// SUM of every part's `dispatchToday`.
  final int totalDispatchQty;

  /// SUM of every part's `totalTrolleys`.
  final int totalTrolleys;

  /// Count of parts where `hasShortage == true`.
  final int shortageCount;

  /// SUM of every part's `shortage` qty (NOS short across all parts).
  final int totalShortageQty;

  const DispatchCalcBatch({
    required this.planDate,
    required this.perPart,
    required this.totalDispatchQty,
    required this.totalTrolleys,
    required this.shortageCount,
    required this.totalShortageQty,
  });

  /// True when at least one part is short. Drives the red alert
  /// banner on the Today's Plan screen.
  bool get hasAnyShortage => shortageCount > 0;
}

/// The calculator. Single static `calculate*` entrypoint pair —
/// `calculatePart` for a single row, `calculateBatch` for a whole day.
class DplDispatchCalculator {
  const DplDispatchCalculator._();

  /// Calculate today's dispatch for one part.
  ///
  /// Pure function. Idempotent. No I/O.
  static DispatchCalcResult calculatePart(DispatchCalcInput input) {
    // Defensive normalisation — UI may pass negatives or nulls-as-0;
    // the calculator treats anything <0 as 0 so the math stays sane.
    final bufferTarget = _nn(input.bufferTargetAtTml);
    final sTml = _nn(input.tmlOpeningStock);
    final cToday = _nn(input.customerPlanToday);
    final sGa = _nn(input.gaOpeningStock);
    final pToday = _nn(input.gaProductionToday);
    final trolleyCap = input.trolleyCapacity > 0 ? input.trolleyCapacity : 1;
    final trips = input.tripsPerDay > 0 ? input.tripsPerDay : 1;

    // Step 1: How much does the customer need to end the day at
    // their safe-stock target?
    final neededAtTml = math.max(0, bufferTarget - sTml + cToday);

    // Step 2: How much can GA spare today?
    final availableAtGa = sGa + pToday;

    // Step 3: Clamp to GA availability.
    final dispatchToday = math.min(neededAtTml, availableAtGa);
    final shortage = math.max(0, neededAtTml - availableAtGa);

    // Step 4: Trolley count from final dispatch qty.
    final totalTrolleys =
        dispatchToday == 0 ? 0 : (dispatchToday + trolleyCap - 1) ~/ trolleyCap;

    // Step 5: Split across trip slots.
    final tripTrolleySplit = _splitTrolleysAcrossTrips(totalTrolleys, trips);
    final tripQtySplit = _trolleysToQty(
      tripTrolleySplit,
      trolleyCap,
      dispatchToday,
    );

    return DispatchCalcResult(
      partId: input.partId,
      customerPn: input.customerPn,
      description: input.description,
      neededAtTml: neededAtTml,
      availableAtGa: availableAtGa,
      dispatchToday: dispatchToday,
      shortage: shortage,
      totalTrolleys: totalTrolleys,
      tripQtySplit: tripQtySplit,
      tripTrolleySplit: tripTrolleySplit,
      projectedTmlClosingStock: sTml - cToday + dispatchToday,
      projectedGaClosingStock: availableAtGa - dispatchToday,
    );
  }

  /// Calculate today's dispatch for every part on the day's plan.
  /// Returns per-part results plus aggregate totals.
  static DispatchCalcBatch calculateBatch({
    required DateTime planDate,
    required List<DispatchCalcInput> inputs,
  }) {
    final perPart = inputs.map(calculatePart).toList(growable: false);
    return DispatchCalcBatch(
      planDate: planDate,
      perPart: perPart,
      totalDispatchQty: perPart.fold<int>(0, (s, r) => s + r.dispatchToday),
      totalTrolleys: perPart.fold<int>(0, (s, r) => s + r.totalTrolleys),
      shortageCount: perPart.where((r) => r.hasShortage).length,
      totalShortageQty: perPart.fold<int>(0, (s, r) => s + r.shortage),
    );
  }

  // ────── helpers ──────

  static int _nn(int v) => v < 0 ? 0 : v;

  /// Distribute `totalTrolleys` across `trips` slots as evenly as
  /// possible, putting the leftover trolleys in the earliest trips.
  ///
  /// Example: 8 trolleys over 6 trips → [2, 2, 1, 1, 1, 1].
  /// The earlier-loaded pattern matches the customer's start-of-shift
  /// buffer-refill behaviour documented in the Trip Plan Excel.
  static List<int> _splitTrolleysAcrossTrips(int totalTrolleys, int trips) {
    final out = List<int>.filled(trips, 0);
    if (totalTrolleys <= 0 || trips <= 0) return out;
    final base = totalTrolleys ~/ trips;
    final remainder = totalTrolleys % trips;
    for (var i = 0; i < trips; i++) {
      out[i] = base + (i < remainder ? 1 : 0);
    }
    return out;
  }

  /// Convert per-trip trolley counts → per-trip NOS qty. The last
  /// non-empty trip absorbs the rounding remainder so the sum of
  /// `tripQtySplit` exactly equals `dispatchToday`.
  static List<int> _trolleysToQty(
    List<int> tripTrolleys,
    int trolleyCap,
    int dispatchToday,
  ) {
    final qty = tripTrolleys
        .map((t) => t * trolleyCap)
        .toList(growable: false);
    final summed = qty.fold<int>(0, (s, v) => s + v);
    final overshoot = summed - dispatchToday;
    if (overshoot <= 0 || dispatchToday == 0) return qty;
    // Pull the overshoot off the last trip that has any qty — that
    // trip's last trolley simply carries fewer pieces than the
    // capacity. Matches how operations partially-loads the final
    // truck of the day.
    final adjusted = List<int>.of(qty);
    for (var i = adjusted.length - 1; i >= 0; i--) {
      if (adjusted[i] > 0) {
        adjusted[i] -= overshoot;
        if (adjusted[i] < 0) adjusted[i] = 0;
        break;
      }
    }
    return adjusted;
  }
}
