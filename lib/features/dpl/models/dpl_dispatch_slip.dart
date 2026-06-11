import '../core/dpl_constants.dart';
import '_json_helpers.dart';

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

/// A single dispatch slip — the digital twin of the printed paper slip
/// in the user's photo (TIAGO 6AB HL ASSY…, qty, datetime, QA / PDI
/// signatures, QR code).
///
/// Goes through Dispatch → QA → PDI → optional mark-dispatched. The
/// `qrPayload` is populated by the backend on PDI approval and is what
/// the slip detail screen renders as a scannable square.
class DplDispatchSlip {
  final int id;
  final String slipNo;
  final int organizationId;

  final int machineId;
  final String machineCode;
  final String machineName;

  final int partId;
  final String customerPartNo;
  final String substratePartNo;
  final String materialCode;
  final String partName;
  final String description;

  final int qty;
  final String status;

  final DplDispatchSlipActor? requestedBy;
  final DateTime? requestedAt;

  final DplDispatchSlipActor? qaApproval;
  final DplDispatchSlipActor? pdiApproval;
  final DplDispatchSlipRejection? rejection;

  final DateTime? dispatchedAt;
  final DplDispatchSlipActor? dispatchedBy;

  /// HMAC-signed JWT-style token rendered as the QR code on the printed
  /// slip. Set the moment PDI approves.
  final String? qrPayload;

  final String notes;

  /// Only present on the create-slip response — qty still available
  /// after this slip is reserved.
  final int? availableQtyAfter;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DplDispatchSlip({
    required this.id,
    required this.slipNo,
    required this.organizationId,
    required this.machineId,
    required this.partId,
    this.machineCode = '',
    this.machineName = '',
    this.customerPartNo = '',
    this.substratePartNo = '',
    this.materialCode = '',
    this.partName = '',
    this.description = '',
    this.qty = 0,
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
    this.availableQtyAfter,
    this.createdAt,
    this.updatedAt,
  });

  factory DplDispatchSlip.fromJson(Map<String, dynamic> json) {
    return DplDispatchSlip(
      id: parseIntOr(json['id']),
      slipNo: parseStringOr(json['slip_no'] ?? json['slipNo']),
      organizationId:
          parseIntOr(json['organization_id'] ?? json['organizationId']),
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      machineCode: parseStringOr(json['machine_code'] ?? json['machineCode']),
      machineName: parseStringOr(json['machine_name'] ?? json['machineName']),
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      customerPartNo: parseStringOr(
        json['customer_part_no'] ?? json['customerPartNo'],
      ),
      substratePartNo: parseStringOr(
        json['substrate_part_no'] ?? json['substratePartNo'],
      ),
      materialCode:
          parseStringOr(json['material_code'] ?? json['materialCode']),
      partName: parseStringOr(json['part_name'] ?? json['partName']),
      description: parseStringOr(json['description']),
      qty: parseIntOr(json['qty']),
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
      availableQtyAfter: parseIntOrNull(
        json['available_qty_after'] ?? json['availableQtyAfter'],
      ),
      createdAt: parseDateTimeOrNull(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTimeOrNull(json['updated_at'] ?? json['updatedAt']),
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
