import '_json_helpers.dart';

/// One row in `dpl_trip_journey_events` — a single checkpoint the trip
/// crossed on its way from our plant gate, into Tata, off the dock, and
/// back out. The append-only feed powers the journey timeline drawer on
/// the manager / dispatch trip-detail surface, and each row is
/// **denormalised**: `actorName` + `actorRole` are captured at write time
/// so a later rename of the user account never rewrites history.
///
/// Server contract:
///   * `event` ∈ {gate_out, tata_gate_in, tata_dock_in, tata_dock_out,
///     tata_gate_out} — five terminal-ordered stages, one per row.
///   * `occurredAt` is UTC on the wire; render with `.toLocal()` and
///     tag "IST" so the operator sees the same clock the guard did.
///   * `payload` is a free-form JSONB blob whose keys depend on the
///     event kind (see [DplTripJourneyPayload]). Always present; empty
///     map on events that carry no data.
class DplTripJourneyEvent {
  final int id;
  final String event;
  final DateTime? occurredAt;

  final int actorUserId;
  final String actorName;
  final String actorRole;

  /// Free-form payload the backend attached to this event. Shape depends
  /// on [event] — see the getters on [DplTripJourneyPayload] for the
  /// known keys. Never `null` — the server sends `{}` when there's
  /// nothing to carry.
  final Map<String, dynamic> payload;

  const DplTripJourneyEvent({
    required this.id,
    required this.event,
    this.occurredAt,
    this.actorUserId = 0,
    this.actorName = '',
    this.actorRole = '',
    this.payload = const {},
  });

  factory DplTripJourneyEvent.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : const <String, dynamic>{};
    return DplTripJourneyEvent(
      id: parseIntOr(json['id']),
      event: parseStringOr(json['event']),
      occurredAt: parseDateTimeOrNull(json['occurred_at'] ?? json['occurredAt']),
      actorUserId: parseIntOr(
        json['actor_user_id'] ?? json['actorUserId'],
      ),
      actorName: parseStringOr(json['actor_name'] ?? json['actorName']),
      actorRole: parseStringOr(json['actor_role'] ?? json['actorRole']),
      payload: payload,
    );
  }

  /// Typed view over [payload]. Kept as a getter (not a field) so the
  /// raw map is always the source of truth — future payload keys just
  /// appear on the wrapper without a model change.
  DplTripJourneyPayload get typedPayload => DplTripJourneyPayload(payload);
}

/// Well-known keys the FE knows how to render for each `event` kind.
/// Anything not listed here is still available under [raw] — the
/// getters exist to keep the drawer widget from reaching into the raw
/// map with string literals in twelve places.
class DplTripJourneyPayload {
  final Map<String, dynamic> raw;
  const DplTripJourneyPayload(this.raw);

  // ── tata_gate_in
  /// LECI barcode / line-entry-control-item number captured at Tata
  /// gate-in. Renders as "LECI #<no>".
  String? get leciNo {
    final v = raw['leci_no'] ?? raw['leciNo'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// LECI truck number as read from the Tata gate scanner.
  String? get leciTruckNo {
    final v = raw['leci_truck_no'] ?? raw['leciTruckNo'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  // ── tata_dock_out
  /// Number of empty trolleys returned at Tata dock-out. `null` on
  /// non-dock-out events (or if the backend omitted it).
  int? get emptyTrolleyCount => parseIntOrNull(
        raw['empty_trolley_count'] ?? raw['emptyTrolleyCount'],
      );

  /// Optional remarks the QRE added at dock-out.
  String? get remarks {
    final v = raw['remarks'];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}

/// Enum-ish for the five known event names. Kept as a plain-string
/// class (not a Dart enum) so an unknown / future event kind from the
/// backend still round-trips through the model without a parse error.
class DplTripJourneyEventKind {
  static const String gateOut = 'gate_out';
  static const String tataGateIn = 'tata_gate_in';
  static const String tataDockIn = 'tata_dock_in';
  static const String tataDockOut = 'tata_dock_out';
  static const String tataGateOut = 'tata_gate_out';

  /// Sequential order the operator sees in the drawer stepper.
  static const List<String> ordered = [
    gateOut,
    tataGateIn,
    tataDockIn,
    tataDockOut,
    tataGateOut,
  ];

  /// Human label rendered next to each stepper node.
  static String label(String event) {
    switch (event) {
      case gateOut:
        return 'Gate-out (our plant)';
      case tataGateIn:
        return 'Tata gate-in';
      case tataDockIn:
        return 'Tata dock-in';
      case tataDockOut:
        return 'Tata dock-out';
      case tataGateOut:
        return 'Tata gate-out';
      default:
        return event.isEmpty ? '-' : event;
    }
  }
}
