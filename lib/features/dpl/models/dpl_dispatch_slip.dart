import '../core/dpl_constants.dart';
import '_json_helpers.dart';
import 'dpl_plant.dart';

/// One actor's signature on a slip (Dispatch creator, QA approver, or
/// PDI approver). Mirrors the `{ user_id, name, at, remarks }` shape
/// the backend returns under `requested_by`, `qa_approval`, and
/// `pdi_approval`.
class DplDispatchSlipActor {
  final int userId;
  final String name;
  final DateTime? at;
  final String? remarks;

  const DplDispatchSlipActor({
    required this.userId,
    this.name = '',
    this.at,
    this.remarks,
  });

  static DplDispatchSlipActor? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return DplDispatchSlipActor(
      userId: parseIntOr(m['user_id'] ?? m['userId']),
      name: parseStringOr(m['name']),
      at: parseDateTimeOrNull(m['at']),
      remarks: m['remarks'] == null ? null : parseStringOr(m['remarks']),
    );
  }
}

/// Details of who/why a slip was rejected. Set on either `qa-reject` or
/// `pdi-reject`; the `role` field tells the UI which station rejected.
class DplDispatchSlipRejection {
  /// `'qa'` or `'pdi'`.
  final String role;
  final int userId;
  final String name;
  final DateTime? at;
  final String reason;

  const DplDispatchSlipRejection({
    required this.role,
    required this.userId,
    this.name = '',
    this.at,
    this.reason = '',
  });

  static DplDispatchSlipRejection? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    return DplDispatchSlipRejection(
      role: parseStringOr(m['role']),
      userId: parseIntOr(m['user_id'] ?? m['userId']),
      name: parseStringOr(m['name']),
      at: parseDateTimeOrNull(m['at']),
      reason: parseStringOr(m['reason']),
    );
  }

  bool get isQa => role.toLowerCase() == 'qa';
  bool get isPdi => role.toLowerCase() == 'pdi';
}

/// Write-side payload for a single slip item, sent inside the `items[]`
/// array of `POST /dispatch/slips`. Only the bare ids + qty — the
/// server hydrates the machine/part display fields and returns them in
/// the response.
class DispatchSlipItemRequest {
  final int machineId;
  final int partId;
  final int qty;

  const DispatchSlipItemRequest({
    required this.machineId,
    required this.partId,
    required this.qty,
  });

  Map<String, dynamic> toJson() => {
        'machine_id': machineId,
        'part_id': partId,
        'qty': qty,
      };
}

/// One line on a multi-item dispatch slip — a `(machine, part, qty)`
/// triplet hydrated server-side with display fields. As of PR 3 the
/// backend returns one of these for every machine/part combination in
/// the slip's items table.
class DplDispatchSlipItem {
  final int machineId;
  final String machineCode;
  final String machineName;

  final int partId;
  final String partName;
  final String customerPartNo;
  final String substratePartNo;
  final String materialCode;
  final String description;

  final int qty;

  const DplDispatchSlipItem({
    required this.machineId,
    required this.partId,
    required this.qty,
    this.machineCode = '',
    this.machineName = '',
    this.partName = '',
    this.customerPartNo = '',
    this.substratePartNo = '',
    this.materialCode = '',
    this.description = '',
  });

  factory DplDispatchSlipItem.fromJson(Map<String, dynamic> json) {
    return DplDispatchSlipItem(
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      machineCode:
          parseStringOr(json['machine_code'] ?? json['machineCode']),
      machineName:
          parseStringOr(json['machine_name'] ?? json['machineName']),
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      partName: parseStringOr(json['part_name'] ?? json['partName']),
      customerPartNo: parseStringOr(
        json['customer_part_no'] ?? json['customerPartNo'],
      ),
      substratePartNo: parseStringOr(
        json['substrate_part_no'] ?? json['substratePartNo'],
      ),
      materialCode:
          parseStringOr(json['material_code'] ?? json['materialCode']),
      description: parseStringOr(json['description']),
      qty: parseIntOr(json['qty']),
    );
  }

  /// Friendly machine label — falls back through code → id.
  String get machineLabel {
    final n = machineName.trim();
    if (n.isNotEmpty) return n;
    final c = machineCode.trim();
    if (c.isNotEmpty) return c;
    return 'Machine #$machineId';
  }

  /// Friendly part label — prefers name, then description, then P/N.
  String get partLabel {
    final n = partName.trim();
    if (n.isNotEmpty) return n;
    final d = description.trim();
    if (d.isNotEmpty) return d;
    final c = customerPartNo.trim();
    if (c.isNotEmpty) return c;
    return 'Part #$partId';
  }
}

/// A multi-item dispatch slip — the digital twin of the printed paper
/// slip but now able to carry multiple `(machine, part, qty)` lines
/// under one plant + vehicle context. Goes through
/// Dispatch → QA → PDI → optional mark-dispatched.
///
/// As of the PR 3 backend refactor:
///   * Slip is scoped to a single plant via `plant.code`
///   * `vehicleNo` is captured at creation, uppercase-normalised
///   * Every line lives in `items[]`; `totalQty` is the server-computed
///     sum across them
///   * `qrPayload` is signed **at creation** (not at PDI approve) — the
///     QR is a stable handle to the slip; the verify endpoint always
///     returns the current DB state
///
/// Legacy single-item convenience getters (`machineLabel`, `partLabel`,
/// `qty`, `customerPartNo`, …) are preserved and derived from the
/// items list so consumers that haven't been refactored yet still
/// compile and render something sensible — they'll be updated in
/// follow-up commits.
class DplDispatchSlip {
  final int id;
  final String slipNo;
  final int organizationId;

  /// Plant the slip belongs to — `{code, name}` only on the slip; the
  /// full `machines[] / stats` payload lives on `GET /plants`.
  final DplPlant plant;

  /// Vehicle number captured at slip creation. Backend trims +
  /// uppercases server-side. Empty string when not provided.
  final String vehicleNo;

  /// Every line on the slip — at least one. Server validates non-empty.
  final List<DplDispatchSlipItem> items;

  /// Server-computed `SUM(items[].qty)`.
  final int totalQty;

  final String status;

  final DplDispatchSlipActor? requestedBy;
  final DateTime? requestedAt;

  final DplDispatchSlipActor? qaApproval;
  final DplDispatchSlipActor? pdiApproval;
  final DplDispatchSlipRejection? rejection;

  final DateTime? dispatchedAt;
  final DplDispatchSlipActor? dispatchedBy;

  /// HMAC-signed JWT-style token rendered as the QR code on the printed
  /// slip. **Signed at creation** as of PR 3 — the same token is valid
  /// through every state transition; the verify endpoint reads live
  /// state from the DB.
  final String? qrPayload;

  final String notes;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DplDispatchSlip({
    required this.id,
    required this.slipNo,
    required this.organizationId,
    required this.plant,
    this.vehicleNo = '',
    this.items = const [],
    this.totalQty = 0,
    this.status = DplDispatchSlipStatus.pendingQa,
    this.requestedBy,
    this.requestedAt,
    this.qaApproval,
    this.pdiApproval,
    this.rejection,
    this.dispatchedAt,
    this.dispatchedBy,
    this.qrPayload,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory DplDispatchSlip.fromJson(Map<String, dynamic> json) {
    // Items — preferred new shape. Fall back to synthesising a single
    // item from legacy flat fields if the response predates PR 3 (e.g.
    // a slip that was created before the migration ran).
    final rawItems = json['items'];
    List<DplDispatchSlipItem> parsedItems;
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map>()
          .map((e) =>
              DplDispatchSlipItem.fromJson(Map<String, dynamic>.from(e)))
          .toList(growable: false);
    } else if (json['machine_id'] != null || json['machineId'] != null) {
      // Legacy single-item slip — wrap it in a one-element items list
      // so the rest of the FE doesn't have to special-case the shape.
      parsedItems = [DplDispatchSlipItem.fromJson(json)];
    } else {
      parsedItems = const [];
    }

    final rawPlant = json['plant'];
    final parsedPlant = rawPlant is Map
        ? DplPlant.fromJson(Map<String, dynamic>.from(rawPlant))
        : const DplPlant(code: '', name: '');

    final declaredTotal =
        parseIntOrNull(json['total_qty'] ?? json['totalQty']);
    final summedTotal =
        parsedItems.fold<int>(0, (sum, it) => sum + it.qty);

    return DplDispatchSlip(
      id: parseIntOr(json['id']),
      slipNo: parseStringOr(json['slip_no'] ?? json['slipNo']),
      organizationId:
          parseIntOr(json['organization_id'] ?? json['organizationId']),
      plant: parsedPlant,
      vehicleNo: parseStringOr(json['vehicle_no'] ?? json['vehicleNo']),
      items: parsedItems,
      totalQty: declaredTotal ?? summedTotal,
      status: parseStringOr(json['status'], DplDispatchSlipStatus.pendingQa),
      requestedBy:
          DplDispatchSlipActor.fromJson(json['requested_by'] ?? json['requestedBy']),
      requestedAt:
          parseDateTimeOrNull(json['requested_at'] ?? json['requestedAt']),
      qaApproval: DplDispatchSlipActor.fromJson(
        json['qa_approval'] ?? json['qaApproval'],
      ),
      pdiApproval: DplDispatchSlipActor.fromJson(
        json['pdi_approval'] ?? json['pdiApproval'],
      ),
      rejection: DplDispatchSlipRejection.fromJson(json['rejection']),
      dispatchedAt:
          parseDateTimeOrNull(json['dispatched_at'] ?? json['dispatchedAt']),
      dispatchedBy: DplDispatchSlipActor.fromJson(
        json['dispatched_by'] ?? json['dispatchedBy'],
      ),
      qrPayload: json['qr_payload'] is String
          ? (json['qr_payload'] as String).trim().isEmpty
              ? null
              : json['qr_payload'] as String
          : json['qrPayload'] is String
              ? (json['qrPayload'] as String).trim().isEmpty
                  ? null
                  : json['qrPayload'] as String
              : null,
      notes: parseStringOr(json['notes']),
      createdAt: parseDateTimeOrNull(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTimeOrNull(json['updated_at'] ?? json['updatedAt']),
    );
  }

  /// True when the slip is single-item — used by legacy UI paths that
  /// render the slip as a single bordered row (the existing PDF,
  /// printable detail screen, request sheet). When false, those paths
  /// should switch to the items-table render (follow-up commits).
  bool get isSingleItem => items.length == 1;

  /// First item or null when the slip has no items. Convenience for the
  /// legacy single-item code paths.
  DplDispatchSlipItem? get firstItem =>
      items.isNotEmpty ? items.first : null;

  // ---------------------------------------------------------------------------
  // Legacy single-item convenience getters
  // ---------------------------------------------------------------------------
  // These derive from `items[].first` (or a sensible multi-item summary
  // when the slip spans multiple lines). They keep the long tail of
  // consumers compiling while we refactor each one to read from items[]
  // directly. Anything reading these getters today renders a "good
  // enough" view; the per-item table comes in the slip-presentation
  // commit.

  int get machineId => firstItem?.machineId ?? 0;
  String get machineCode => firstItem?.machineCode ?? '';
  String get machineName => firstItem?.machineName ?? '';
  int get partId => firstItem?.partId ?? 0;
  String get partName => firstItem?.partName ?? '';
  String get customerPartNo => firstItem?.customerPartNo ?? '';
  String get substratePartNo => firstItem?.substratePartNo ?? '';
  String get materialCode => firstItem?.materialCode ?? '';
  String get description => firstItem?.description ?? '';

  /// Alias for `totalQty` so legacy consumers reading `slip.qty` still
  /// get the right number.
  int get qty => totalQty;

  /// Machine label — first item's label, or a summary when multi-item.
  String get machineLabel {
    if (items.isEmpty) return 'Machine #$machineId';
    if (items.length == 1) return items.first.machineLabel;
    // Multi-item slip across distinct machines.
    final distinctMachines =
        items.map((i) => i.machineId).toSet().length;
    if (distinctMachines == 1) return items.first.machineLabel;
    return '$distinctMachines machines';
  }

  /// Part label — first item's, or a summary like "3 items" when multi.
  String get partLabel {
    if (items.isEmpty) return 'Part #$partId';
    if (items.length == 1) return items.first.partLabel;
    return '${items.length} items';
  }

  /// True when the slip is ready to print: PDI has approved and the
  /// signed QR payload is populated.
  bool get hasPrintableQr =>
      DplDispatchSlipStatus.isApproved(status) ||
      status == DplDispatchSlipStatus.dispatched && (qrPayload ?? '').isNotEmpty;

  /// Per-station state machine view. Tells the printable slip whether
  /// to print "Approved by QA" / "Pending QA" / "Rejected by QA" so the
  /// paper is self-describing about where the workflow stands.
  DispatchStationState get qaState {
    final r = rejection;
    if (r != null && r.isQa) return DispatchStationState.rejected;
    if (qaApproval != null) return DispatchStationState.approved;
    // Anything that hasn't been QA-approved yet (and wasn't rejected
    // at QA) is still pending QA, regardless of overall status —
    // covers `pending_qa` and the edge case where it's still loading.
    return DispatchStationState.pending;
  }

  DispatchStationState get pdiState {
    final r = rejection;
    if (r != null && r.isPdi) return DispatchStationState.rejected;
    if (pdiApproval != null) return DispatchStationState.approved;
    return DispatchStationState.pending;
  }
}

/// Per-station (QA / PDI) workflow state used by the printable slip's
/// signature blocks to render "Approved by …", "Pending …", or
/// "Rejected by …" in a self-describing way.
enum DispatchStationState { pending, approved, rejected }

/// Rolling counts the backend returns alongside the page so the UI can
/// render badge counts on the inbox tabs without a second round-trip.
/// These ignore `machine_id` / `part_id` / `q` filters so the badge stays
/// stable as the user types into the search box. As of the 2026-06-11
/// backend update, each count is paired with a `*_qty` SUM rollup so the
/// production-summary banner can show qty-weighted totals too.
class DplDispatchSlipTotals {
  final int pendingQa;
  final int pendingPdi;
  final int approved;
  final int rejected;
  final int dispatched;

  // Qty rollups — SUM(qty) for slips in each status, role-scoped and
  // filter-ignoring (same scope as the counts).
  final int pendingQaQty;
  final int pendingPdiQty;
  final int approvedQty;
  final int rejectedQty;
  final int dispatchedQty;

  const DplDispatchSlipTotals({
    this.pendingQa = 0,
    this.pendingPdi = 0,
    this.approved = 0,
    this.rejected = 0,
    this.dispatched = 0,
    this.pendingQaQty = 0,
    this.pendingPdiQty = 0,
    this.approvedQty = 0,
    this.rejectedQty = 0,
    this.dispatchedQty = 0,
  });

  factory DplDispatchSlipTotals.fromJson(Map<String, dynamic> json) {
    return DplDispatchSlipTotals(
      pendingQa: parseIntOr(json['pending_qa_count'] ?? json['pendingQaCount']),
      pendingPdi:
          parseIntOr(json['pending_pdi_count'] ?? json['pendingPdiCount']),
      approved: parseIntOr(json['approved_count'] ?? json['approvedCount']),
      rejected: parseIntOr(json['rejected_count'] ?? json['rejectedCount']),
      dispatched:
          parseIntOr(json['dispatched_count'] ?? json['dispatchedCount']),
      pendingQaQty:
          parseIntOr(json['pending_qa_qty'] ?? json['pendingQaQty']),
      pendingPdiQty:
          parseIntOr(json['pending_pdi_qty'] ?? json['pendingPdiQty']),
      approvedQty: parseIntOr(json['approved_qty'] ?? json['approvedQty']),
      rejectedQty: parseIntOr(json['rejected_qty'] ?? json['rejectedQty']),
      dispatchedQty:
          parseIntOr(json['dispatched_qty'] ?? json['dispatchedQty']),
    );
  }

  /// Qty currently moving through QA + PDI + approved-but-not-yet-shipped
  /// — the "In pipeline" tile on the totals banner.
  int get inPipelineQty => pendingQaQty + pendingPdiQty + approvedQty;
}

/// One page of slips + pagination + role-aware totals.
class DplDispatchSlipPage {
  final List<DplDispatchSlip> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final DplDispatchSlipTotals totals;

  const DplDispatchSlipPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.totals,
  });

  factory DplDispatchSlipPage.empty() => const DplDispatchSlipPage(
        items: [],
        page: 1,
        limit: 50,
        total: 0,
        totalPages: 0,
        totals: DplDispatchSlipTotals(),
      );

  bool get hasMore => page < totalPages;

  factory DplDispatchSlipPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => DplDispatchSlip.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplDispatchSlip>[];

    final rawPagination = json['pagination'];
    final pagination = rawPagination is Map
        ? Map<String, dynamic>.from(rawPagination)
        : const <String, dynamic>{};

    final rawTotals = json['totals'];
    final totals = rawTotals is Map
        ? DplDispatchSlipTotals.fromJson(
            Map<String, dynamic>.from(rawTotals),
          )
        : const DplDispatchSlipTotals();

    return DplDispatchSlipPage(
      items: items,
      page: parseIntOr(pagination['page'], 1),
      limit: parseIntOr(pagination['limit'], items.length),
      total: parseIntOr(pagination['total'], items.length),
      totalPages:
          parseIntOr(pagination['totalPages'] ?? pagination['total_pages']),
      totals: totals,
    );
  }
}

/// Payload returned by the public `/dispatch/slips/verify?token=` endpoint.
/// Wraps the slip with a `verified` flag and the decoded signed payload
/// so the gate-staff verifier UI can show "this is a genuine slip" or
/// "this token has been tampered with".
class DplDispatchSlipVerification {
  final bool verified;
  final DplDispatchSlip? slip;
  final Map<String, dynamic>? signedPayload;

  const DplDispatchSlipVerification({
    required this.verified,
    this.slip,
    this.signedPayload,
  });

  factory DplDispatchSlipVerification.fromJson(Map<String, dynamic> json) {
    final slipJson = json['slip'] ?? json;
    return DplDispatchSlipVerification(
      verified: json['verified'] == true,
      slip: slipJson is Map
          ? DplDispatchSlip.fromJson(Map<String, dynamic>.from(slipJson))
          : null,
      signedPayload: json['signed_payload'] is Map
          ? Map<String, dynamic>.from(json['signed_payload'] as Map)
          : null,
    );
  }
}
