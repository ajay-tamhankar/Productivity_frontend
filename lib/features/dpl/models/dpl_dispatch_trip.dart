import '_json_helpers.dart';

/// Lifecycle for a manager-submitted dispatch trip.
///
/// `open` — at least one plan is unslipped.
/// `partial` — some plans converted to slips, others still open.
/// `fulfilled` — every plan has been converted to a slip.
/// `cancelled` — manager-cancelled before slipping OR force-cancelled
///               by admin / supervisor OR auto_expired by the daily
///               04:00 IST cron.
class DplTripStatus {
  static const String open = 'open';
  static const String partial = 'partial';
  static const String fulfilled = 'fulfilled';
  static const String cancelled = 'cancelled';

  static const List<String> all = [open, partial, fulfilled, cancelled];

  static String label(String s) {
    switch (s) {
      case open:
        return 'Open';
      case partial:
        return 'Partial';
      case fulfilled:
        return 'Fulfilled';
      case cancelled:
        return 'Cancelled';
      default:
        return s.isEmpty ? '-' : s[0].toUpperCase() + s.substring(1);
    }
  }

  /// True while the trip still has at least one unslipped plan.
  static bool hasOpenPlans(String s) => s == open || s == partial;
}

/// Lifecycle for a single line item inside a trip.
class DplTripPlanStatus {
  static const String open = 'open';
  static const String slipCreated = 'slip_created';
  static const String dispatched = 'dispatched';
  static const String cancelled = 'cancelled';

  static const List<String> all = [open, slipCreated, dispatched, cancelled];

  /// True for plans the dispatcher can still pick + edit.
  static bool isBookable(String s) => s == open;
}

/// One plan (line item) inside a trip. Each plan is a single
/// `(machine_id, part_id, qty)` triple plus its lifecycle status and
/// the snapshot of what the dispatch formula suggested at submit time
/// (drives variance reporting later).
///
/// Embedded part / machine fields are eagerly populated by the
/// backend on GET. Falls back gracefully if a future API version
/// drops the embedded shape.
class DplTripPlan {
  final int id;
  final int tripId;

  // ── relations
  final int machineId;
  final String machineName;
  final int partId;
  final String customerPn;
  final String description;
  final String partName;

  // ── allocation
  final int qty;
  final int? suggestedQty;

  /// Customer-supplied units per pack for this part (migration 049).
  /// Drives the "Pack: N NOS" hint + multiple-of-pack warning under
  /// the qty input. `null` when the part doesn't have a pack qty
  /// configured yet — UI hides the hint in that case.
  final int? packagingQty;
  final String status;
  final int? slipId;
  final String? varianceNote;

  // ── audit
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DplTripPlan({
    required this.id,
    required this.tripId,
    required this.machineId,
    required this.partId,
    required this.qty,
    required this.status,
    this.machineName = '',
    this.customerPn = '',
    this.description = '',
    this.partName = '',
    this.suggestedQty,
    this.packagingQty,
    this.slipId,
    this.varianceNote,
    this.createdAt,
    this.updatedAt,
  });

  factory DplTripPlan.fromJson(Map<String, dynamic> json) {
    // Backend may inline the part/machine objects under nested keys
    // or as flat fields — handle both so a backend shape tweak doesn't
    // silently null out the labels.
    Map<String, dynamic> part = const {};
    final rawPart = json['part'];
    if (rawPart is Map) part = Map<String, dynamic>.from(rawPart);

    Map<String, dynamic> machine = const {};
    final rawMachine = json['machine'];
    if (rawMachine is Map) machine = Map<String, dynamic>.from(rawMachine);

    return DplTripPlan(
      id: parseIntOr(json['id']),
      tripId: parseIntOr(json['trip_id'] ?? json['tripId']),
      machineId: parseIntOr(
        json['machine_id'] ?? json['machineId'] ?? machine['id'],
      ),
      machineName: parseStringOr(
        json['machine_name'] ??
            json['machineName'] ??
            machine['machine_name'] ??
            machine['name'],
      ),
      partId: parseIntOr(
        json['part_id'] ?? json['partId'] ?? part['id'],
      ),
      customerPn: parseStringOr(
        json['customer_pn'] ??
            json['customerPn'] ??
            part['customer_part_no'] ??
            part['customerPartNo'],
      ),
      description: parseStringOr(
        json['description'] ?? part['description'],
      ),
      partName: parseStringOr(
        json['part_name'] ??
            json['partName'] ??
            part['part_name'] ??
            part['partName'] ??
            part['name'],
      ),
      qty: parseIntOr(json['qty']),
      suggestedQty: parseIntOrNull(
        json['suggested_qty'] ?? json['suggestedQty'],
      ),
      packagingQty: parseIntOrNull(
        json['packaging_qty'] ??
            json['packagingQty'] ??
            part['packaging_qty'] ??
            part['packagingQty'],
      ),
      status: parseStringOr(json['status'], DplTripPlanStatus.open),
      slipId: parseIntOrNull(json['slip_id'] ?? json['slipId']),
      varianceNote: json['variance_note'] is String
          ? json['variance_note'] as String
          : (json['varianceNote'] is String
              ? json['varianceNote'] as String
              : null),
      createdAt: parseDateTimeOrNull(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTimeOrNull(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

/// One full trip. `plans` is included by default on both list + detail
/// responses — the FE always needs them to render the trip card.
class DplTrip {
  final int id;
  final String plantCode;
  final String plantName;
  final int tripNumber;
  final String status;
  final String? vehicleNo;
  final String? notes;
  final int submittedByUserId;
  final String submittedByName;
  final DateTime? submittedAt;
  final DateTime? cancelledAt;
  final int? cancelledByUserId;
  final String? cancelReason;
  final List<DplTripPlan> plans;

  // Rolled-up counts the backend computes for the list view. Optional
  // because POST /dispatch/trips may omit them (FE derives from plans).
  final int? planCount;
  final int? openPlanCount;
  final int? slippedPlanCount;
  final int? dispatchedPlanCount;
  final int? cancelledPlanCount;
  final int? totalQty;
  final int? openQty;
  final int? slippedQty;
  final int? dispatchedQty;
  final int? cancelledQty;

  const DplTrip({
    required this.id,
    required this.plantCode,
    required this.tripNumber,
    required this.status,
    this.plantName = '',
    this.vehicleNo,
    this.notes,
    this.submittedByUserId = 0,
    this.submittedByName = '',
    this.submittedAt,
    this.cancelledAt,
    this.cancelledByUserId,
    this.cancelReason,
    this.plans = const [],
    this.planCount,
    this.openPlanCount,
    this.slippedPlanCount,
    this.dispatchedPlanCount,
    this.cancelledPlanCount,
    this.totalQty,
    this.openQty,
    this.slippedQty,
    this.dispatchedQty,
    this.cancelledQty,
  });

  factory DplTrip.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> submittedBy = const {};
    final rawBy = json['submitted_by'] ?? json['submittedBy'];
    if (rawBy is Map) submittedBy = Map<String, dynamic>.from(rawBy);

    final rawPlans = json['plans'];
    final plans = rawPlans is List
        ? rawPlans
            .whereType<Map>()
            .map((p) => DplTripPlan.fromJson(Map<String, dynamic>.from(p)))
            .toList(growable: false)
        : const <DplTripPlan>[];

    return DplTrip(
      id: parseIntOr(json['id']),
      plantCode: parseStringOr(json['plant_code'] ?? json['plantCode']),
      plantName: parseStringOr(json['plant_name'] ?? json['plantName']),
      tripNumber: parseIntOr(json['trip_number'] ?? json['tripNumber']),
      status: parseStringOr(json['status'], DplTripStatus.open),
      vehicleNo: json['vehicle_no'] is String
          ? json['vehicle_no'] as String
          : (json['vehicleNo'] is String ? json['vehicleNo'] as String : null),
      notes: json['notes'] is String ? json['notes'] as String : null,
      submittedByUserId: parseIntOr(
        rawBy is int
            ? rawBy
            : (submittedBy['id'] ?? json['submitted_by_user_id']),
      ),
      submittedByName: rawBy is Map
          ? parseStringOr(submittedBy['name'] ?? submittedBy['username'])
          : '',
      submittedAt:
          parseDateTimeOrNull(json['submitted_at'] ?? json['submittedAt']),
      cancelledAt:
          parseDateTimeOrNull(json['cancelled_at'] ?? json['cancelledAt']),
      cancelledByUserId: parseIntOrNull(
        json['cancelled_by_user_id'] ?? json['cancelledByUserId'],
      ),
      cancelReason: json['cancel_reason'] is String
          ? json['cancel_reason'] as String
          : (json['cancelReason'] is String
              ? json['cancelReason'] as String
              : null),
      plans: plans,
      planCount: parseIntOrNull(json['plan_count'] ?? json['planCount']),
      openPlanCount:
          parseIntOrNull(json['open_plan_count'] ?? json['openPlanCount']),
      slippedPlanCount: parseIntOrNull(
          json['slipped_plan_count'] ?? json['slippedPlanCount']),
      dispatchedPlanCount: parseIntOrNull(
          json['dispatched_plan_count'] ?? json['dispatchedPlanCount']),
      cancelledPlanCount: parseIntOrNull(
          json['cancelled_plan_count'] ?? json['cancelledPlanCount']),
      totalQty: parseIntOrNull(json['total_qty'] ?? json['totalQty']),
      openQty: parseIntOrNull(json['open_qty'] ?? json['openQty']),
      slippedQty: parseIntOrNull(json['slipped_qty'] ?? json['slippedQty']),
      dispatchedQty:
          parseIntOrNull(json['dispatched_qty'] ?? json['dispatchedQty']),
      cancelledQty:
          parseIntOrNull(json['cancelled_qty'] ?? json['cancelledQty']),
    );
  }
}

/// Body shape for `POST /dispatch/trips`. The FE builds one of these
/// per drafted trip on the Plan Trip screen and POSTs sequentially.
class DplTripCreateRequest {
  final String plantCode;
  final String? vehicleNo;
  final String? notes;
  final List<DplTripCreatePlan> plans;

  const DplTripCreateRequest({
    required this.plantCode,
    required this.plans,
    this.vehicleNo,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'plant_code': plantCode,
        if (vehicleNo != null && vehicleNo!.isNotEmpty)
          'vehicle_no': vehicleNo,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
        'plans': [for (final p in plans) p.toJson()],
      };
}

class DplTripCreatePlan {
  final int machineId;
  final int partId;
  final int qty;
  final int? suggestedQty;

  const DplTripCreatePlan({
    required this.machineId,
    required this.partId,
    required this.qty,
    this.suggestedQty,
  });

  Map<String, dynamic> toJson() => {
        'machine_id': machineId,
        'part_id': partId,
        'qty': qty,
        if (suggestedQty != null) 'suggested_qty': suggestedQty,
      };
}

/// Paginated list response shape for `GET /dispatch/trips`.
class DplTripListResponse {
  final List<DplTrip> trips;
  final int total;
  final int limit;
  final int offset;

  const DplTripListResponse({
    this.trips = const [],
    this.total = 0,
    this.limit = 0,
    this.offset = 0,
  });

  factory DplTripListResponse.fromJson(Map<String, dynamic> json) {
    final rawTrips = json['trips'];
    final trips = rawTrips is List
        ? rawTrips
            .whereType<Map>()
            .map((t) => DplTrip.fromJson(Map<String, dynamic>.from(t)))
            .toList(growable: false)
        : const <DplTrip>[];

    Map<String, dynamic> page = const {};
    final rawPage = json['page'];
    if (rawPage is Map) page = Map<String, dynamic>.from(rawPage);

    return DplTripListResponse(
      trips: trips,
      total: parseIntOr(page['total']),
      limit: parseIntOr(page['limit']),
      offset: parseIntOr(page['offset']),
    );
  }
}
