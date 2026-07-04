import '_json_helpers.dart';

/// Which manager-editable field this row represents. The 4 endpoints
/// (stocking-norms / customer-opening-stocks / customer-todays-plans /
/// packaging-qtys) share the same response shape; this enum lets one
/// parameterized edit screen serve all of them.
enum DplPartFieldKind {
  /// Configured ONCE per part. Safe-stock target at the customer's end.
  stockingNorm('stocking_norm', 'Stocking Norm', 'Update once'),

  /// Refreshed MONTHLY. What the customer currently holds in inventory.
  customerOpeningStock(
    'customer_opening_stock',
    'Customer Opening Stock',
    'Update monthly',
  ),

  /// Updated DAILY. Customer's planned production / consumption today.
  customerTodayPlan(
    'customer_today_plan',
    'Customer\'s Today\'s Plan',
    'Update daily',
  ),

  /// Customer-supplied packaging quantity per part (units per pack,
  /// e.g. 14 NOS / pack for TIAGO parts, 140 for HMSL KLG). Drives
  /// the "Pack" hint + multiple-of-pack warning next to the qty input
  /// on every dispatch surface. Configured once per part — backend
  /// does NOT enforce qty as a multiple; partial packs are valid for
  /// stock-short or pilot scenarios.
  packagingQty('packaging_qty', 'Packaging Qty', 'Update once'),

  /// Refreshed MONTHLY. Opening stock currently held at GA (Grupo
  /// Antolin) per part — the manual seed for the buffer report's
  /// "Opn Stock at GA" roll-forward column.
  gaOpeningStock(
    'ga_opening_stock',
    'Opening Stock at GA',
    'Update monthly',
  );

  /// The backend's `field` discriminator string + the per-entry value
  /// key. Used both for parsing the GET response and for building the
  /// PUT request body shape.
  final String apiField;

  /// User-facing screen title.
  final String label;

  /// Short cadence hint shown on the hub card.
  final String cadence;

  const DplPartFieldKind(this.apiField, this.label, this.cadence);

  /// The per-part fields that feed the DAILY dispatch formula + planning
  /// readiness. Excludes [gaOpeningStock], which only seeds the buffer
  /// report's "Opn Stock at GA" column and must NOT gate daily dispatch
  /// readiness or be prefetched by the dispatch-planning screens. Those
  /// screens iterate this list instead of [values].
  static const List<DplPartFieldKind> dispatchPlanningKinds = [
    stockingNorm,
    customerOpeningStock,
    customerTodayPlan,
    packagingQty,
  ];
}

/// One row in the per-part field listing. `value` is `null` when the
/// part hasn't been configured for this field yet (only surfaced when
/// the GET was called with `?with_null=true`).
class DplPartFieldEntry {
  final int partId;
  final String customerPn;
  final String description;
  final String partName;
  final String machineName;
  final String? materialCode;

  /// The field value, parsed from whichever key the backend used for
  /// this field kind (`stocking_norm` / `customer_opening_stock` /
  /// `customer_today_plan`). Null when the part isn't configured yet.
  final int? value;

  const DplPartFieldEntry({
    required this.partId,
    this.customerPn = '',
    this.description = '',
    this.partName = '',
    this.machineName = '',
    this.materialCode,
    this.value,
  });

  factory DplPartFieldEntry.fromJson(
    Map<String, dynamic> json,
    DplPartFieldKind kind,
  ) {
    return DplPartFieldEntry(
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      customerPn: parseStringOr(json['customer_pn'] ?? json['customerPn']),
      description: parseStringOr(json['description']),
      partName: parseStringOr(json['part_name'] ?? json['partName']),
      machineName: parseStringOr(json['machine_name'] ?? json['machineName']),
      materialCode: json['material_code'] is String
          ? json['material_code'] as String
          : null,
      value: parseIntOrNull(json[kind.apiField]),
    );
  }
}

/// Rolling counts the backend returns alongside the entries.
/// Drives the "12/13 configured" caption on the hub cards.
class DplPartFieldTotals {
  final int totalParts;
  final int configured;
  final int unconfigured;

  const DplPartFieldTotals({
    this.totalParts = 0,
    this.configured = 0,
    this.unconfigured = 0,
  });

  factory DplPartFieldTotals.fromJson(Map<String, dynamic> json) {
    return DplPartFieldTotals(
      totalParts: parseIntOr(json['total_parts'] ?? json['totalParts']),
      configured: parseIntOr(json['configured']),
      unconfigured: parseIntOr(json['unconfigured']),
    );
  }

  /// True when every part has this field set.
  bool get isFullyConfigured =>
      unconfigured == 0 && totalParts > 0;
}

/// Full GET response page for any of the 3 endpoints. The `field`
/// discriminator echoes back which field the backend served.
class DplPartFieldPage {
  final DplPartFieldKind kind;
  final List<DplPartFieldEntry> entries;
  final DplPartFieldTotals totals;

  const DplPartFieldPage({
    required this.kind,
    this.entries = const [],
    this.totals = const DplPartFieldTotals(),
  });

  factory DplPartFieldPage.fromJson(
    Map<String, dynamic> json,
    DplPartFieldKind kind,
  ) {
    return DplPartFieldPage(
      kind: kind,
      entries: (json['entries'] is List)
          ? (json['entries'] as List)
              .whereType<Map>()
              .map((e) => DplPartFieldEntry.fromJson(
                    Map<String, dynamic>.from(e),
                    kind,
                  ))
              .toList(growable: false)
          : const [],
      totals: (json['totals'] is Map)
          ? DplPartFieldTotals.fromJson(
              Map<String, dynamic>.from(json['totals'] as Map),
            )
          : const DplPartFieldTotals(),
    );
  }
}

/// One row in the PUT bulk-upsert body. `value` may be `null` — that
/// explicitly clears the column back to NULL on the backend.
class DplPartFieldUpsertRequest {
  final int partId;
  final int? value;

  const DplPartFieldUpsertRequest({required this.partId, this.value});

  Map<String, dynamic> toJson(DplPartFieldKind kind) {
    return {
      'part_id': partId,
      kind.apiField: value,
    };
  }
}

/// Result block in the PUT response. `upserted_count` is the total
/// rows touched; `updated_count` is the subset that actually changed
/// a value; `unchanged_count` is the rest (no SQL write fired).
class DplPartFieldUpsertResult {
  final DplPartFieldKind kind;
  final int upsertedCount;
  final int updatedCount;
  final int unchangedCount;

  const DplPartFieldUpsertResult({
    required this.kind,
    this.upsertedCount = 0,
    this.updatedCount = 0,
    this.unchangedCount = 0,
  });

  factory DplPartFieldUpsertResult.fromJson(
    Map<String, dynamic> json,
    DplPartFieldKind kind,
  ) {
    return DplPartFieldUpsertResult(
      kind: kind,
      upsertedCount: parseIntOr(json['upserted_count'] ?? json['upsertedCount']),
      updatedCount: parseIntOr(json['updated_count'] ?? json['updatedCount']),
      unchangedCount:
          parseIntOr(json['unchanged_count'] ?? json['unchangedCount']),
    );
  }
}
