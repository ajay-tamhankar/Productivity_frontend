import '_json_helpers.dart';
import 'dpl_dispatch_slip.dart';
import 'dpl_dispatch_trip.dart';
import 'dpl_trip_journey_event.dart';

/// One flattened line on the consolidated trip page — a `(slip_no,
/// invoice_no, machine, part, qty)` row rolled up from every slip on
/// the trip. The consolidated screen renders these in a single compact
/// table (with a running index) so the guard / driver / dock QRE can
/// verify contents at a glance without paging through per-slip PDFs.
class DplConsolidatedSlipRow {
  final int slipId;
  final String slipNo;
  final String invoiceNo;
  final String machineCode;
  final String machineName;
  final String customerPartNo;
  final String partName;
  final String description;
  final int qty;

  const DplConsolidatedSlipRow({
    required this.slipId,
    required this.slipNo,
    this.invoiceNo = '',
    this.machineCode = '',
    this.machineName = '',
    this.customerPartNo = '',
    this.partName = '',
    this.description = '',
    this.qty = 0,
  });

  /// Friendly machine label — falls back through name → code → id.
  String get machineLabel {
    final n = machineName.trim();
    if (n.isNotEmpty) return n;
    final c = machineCode.trim();
    if (c.isNotEmpty) return c;
    return 'Machine #$slipId';
  }

  /// Friendly part label — prefers name, then description, then P/N.
  String get partLabel {
    final n = partName.trim();
    if (n.isNotEmpty) return n;
    final d = description.trim();
    if (d.isNotEmpty) return d;
    final c = customerPartNo.trim();
    if (c.isNotEmpty) return c;
    return '-';
  }
}

/// Full payload behind `GET /dispatch/trips/:id/consolidated-slip` —
/// the driver's phone view. Bundles the trip header, every slip's
/// hydrated items, a freshly-minted trip-level QR token (used by the
/// gate scanner + Tata dock QRE), and the journey event feed so the
/// consumer can render current stage without a second round-trip.
///
/// The QR token is **deterministic** per trip (signed with
/// `noTimestamp:true` on the backend), so re-fetching the same trip
/// produces the same token — safe to embed in print PDFs.
class DplConsolidatedSlip {
  final DplTrip trip;
  final List<DplDispatchSlip> slips;
  final String qrToken;
  final List<DplTripJourneyEvent> events;

  const DplConsolidatedSlip({
    required this.trip,
    this.slips = const [],
    this.qrToken = '',
    this.events = const [],
  });

  factory DplConsolidatedSlip.fromJson(Map<String, dynamic> json) {
    // The trip block is the standard shape from tripService.shape() —
    // parse via DplTrip.fromJson (which accepts either the raw shape or
    // a wrapping envelope, matching the API service tolerance).
    final rawTrip = json['trip'];
    final DplTrip trip = rawTrip is Map
        ? DplTrip.fromJson(Map<String, dynamic>.from(rawTrip))
        : DplTrip.fromJson(json);

    // Every slip on this trip, hydrated with items + machine/part
    // display fields (server-side batched). Order matches the backend's
    // getSlipsByTripId result.
    final rawSlips = json['slips'];
    final slips = rawSlips is List
        ? rawSlips
            .whereType<Map>()
            .map((s) =>
                DplDispatchSlip.fromJson(Map<String, dynamic>.from(s)))
            .toList(growable: false)
        : const <DplDispatchSlip>[];

    // Journey events already sorted oldest-first server-side; we don't
    // re-sort here so the FE renders exactly what the backend saw.
    final rawEvents = json['events'];
    final events = rawEvents is List
        ? rawEvents
            .whereType<Map>()
            .map((e) => DplTripJourneyEvent.fromJson(
                Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <DplTripJourneyEvent>[];

    return DplConsolidatedSlip(
      trip: trip,
      slips: slips,
      qrToken: parseStringOr(json['qr_token'] ?? json['qrToken']),
      events: events,
    );
  }

  /// Flattens every slip's items into a single ordered list of
  /// display rows — the shape the consolidated table + PDF render off
  /// of. One row per `(slip, item)` pair so a slip with multiple items
  /// contributes multiple rows and the slip_no repeats down the "#"
  /// column exactly like on paper.
  List<DplConsolidatedSlipRow> flattenRows() {
    final rows = <DplConsolidatedSlipRow>[];
    for (final s in slips) {
      if (s.items.isEmpty) {
        // Defensive: legacy slips with no items still contribute a
        // single row so the driver sees the slip number.
        rows.add(DplConsolidatedSlipRow(
          slipId: s.id,
          slipNo: s.slipNo,
          invoiceNo: s.invoiceNo.trim(),
        ));
        continue;
      }
      for (final it in s.items) {
        rows.add(DplConsolidatedSlipRow(
          slipId: s.id,
          slipNo: s.slipNo,
          invoiceNo: s.invoiceNo.trim(),
          machineCode: it.machineCode,
          machineName: it.machineName,
          customerPartNo: it.customerPartNo,
          partName: it.partName,
          description: it.description,
          qty: it.qty,
        ));
      }
    }
    return rows;
  }

  /// Total NOS across every slip on the trip — server-computed on each
  /// slip, summed here so the header can render "N NOS across M slips".
  int get totalQty => slips.fold<int>(0, (s, x) => s + x.totalQty);

  /// Truck plate from the first slip that carries one, then falls back
  /// to the trip. Consolidated slips are single-vehicle per trip so
  /// any slip's vehicle is the trip's.
  String get vehicleNo {
    for (final s in slips) {
      final v = s.vehicleNo.trim();
      if (v.isNotEmpty) return v;
    }
    return trip.vehicleNo?.trim() ?? '';
  }
}
