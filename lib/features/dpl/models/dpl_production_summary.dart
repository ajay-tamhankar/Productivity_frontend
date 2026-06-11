import '_json_helpers.dart';

/// One row of the production-summary aggregate — total quantity produced
/// for a single `(organization, machine, part)` bucket, kept fresh by
/// Postgres triggers on `dpl_production_plan_items`.
///
/// Drives the Production Summary screen shown to the new Dispatch / QA /
/// PDI roles (and exposed to the Manager too).
class DplProductionSummary {
  final int id;
  final int organizationId;
  final int machineId;
  final int partId;

  final String machineCode;
  final String machineName;

  final String customerPartNo;
  final String substratePartNo;
  final String materialCode;
  final String partName;
  final String description;

  final int totalActualQty;
  final int totalPlanQty;

  /// `total_actual_qty − sum(qty of non-rejected dispatch slips)`.
  /// Drives the qty-field cap on the Request Dispatch Slip form so the
  /// UI never lets Dispatch ask for more than what's still in stock.
  final int availableForDispatchQty;

  final int completedItems;
  final int inProgressItems;
  final int pendingItems;
  final int skippedItems;

  final DateTime? firstProducedAt;
  final DateTime? lastProducedAt;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DplProductionSummary({
    required this.id,
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
    this.totalActualQty = 0,
    this.totalPlanQty = 0,
    this.availableForDispatchQty = 0,
    this.completedItems = 0,
    this.inProgressItems = 0,
    this.pendingItems = 0,
    this.skippedItems = 0,
    this.firstProducedAt,
    this.lastProducedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DplProductionSummary.fromJson(Map<String, dynamic> json) {
    return DplProductionSummary(
      id: parseIntOr(json['id']),
      organizationId: parseIntOr(json['organization_id'] ?? json['organizationId']),
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      machineCode: parseStringOr(json['machine_code'] ?? json['machineCode']),
      machineName: parseStringOr(json['machine_name'] ?? json['machineName']),
      customerPartNo: parseStringOr(
        json['customer_part_no'] ?? json['customerPartNo'],
      ),
      substratePartNo: parseStringOr(
        json['substrate_part_no'] ?? json['substratePartNo'],
      ),
      materialCode: parseStringOr(json['material_code'] ?? json['materialCode']),
      partName: parseStringOr(json['part_name'] ?? json['partName']),
      description: parseStringOr(json['description']),
      totalActualQty: parseIntOr(json['total_actual_qty'] ?? json['totalActualQty']),
      totalPlanQty: parseIntOr(json['total_plan_qty'] ?? json['totalPlanQty']),
      availableForDispatchQty: parseIntOr(
        json['available_for_dispatch_qty'] ??
            json['availableForDispatchQty'] ??
            json['total_actual_qty'] ??
            json['totalActualQty'],
      ),
      completedItems: parseIntOr(json['completed_items'] ?? json['completedItems']),
      inProgressItems:
          parseIntOr(json['in_progress_items'] ?? json['inProgressItems']),
      pendingItems: parseIntOr(json['pending_items'] ?? json['pendingItems']),
      skippedItems: parseIntOr(json['skipped_items'] ?? json['skippedItems']),
      firstProducedAt: parseDateTimeOrNull(
        json['first_produced_at'] ?? json['firstProducedAt'],
      ),
      lastProducedAt: parseDateTimeOrNull(
        json['last_produced_at'] ?? json['lastProducedAt'],
      ),
      createdAt: parseDateTimeOrNull(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDateTimeOrNull(json['updated_at'] ?? json['updatedAt']),
    );
  }

  /// Plan completion expressed as a 0..1 fraction. Guards against
  /// divide-by-zero on rows that have never been planned.
  double get completionRatio {
    if (totalPlanQty <= 0) return 0;
    final r = totalActualQty / totalPlanQty;
    if (r.isNaN || r.isInfinite) return 0;
    return r.clamp(0, 1).toDouble();
  }

  /// Friendly machine label — falls back through code → id so the UI
  /// never renders an empty cell.
  String get machineLabel {
    final n = machineName.trim();
    if (n.isNotEmpty) return n;
    final c = machineCode.trim();
    if (c.isNotEmpty) return c;
    return 'Machine #$machineId';
  }

  /// Friendly part label — prefers the part name, then description, then
  /// the customer part number, then the id.
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

/// Rolling totals returned alongside the page of items — backend
/// computes these over the *filtered* set, not just the current page.
class DplProductionSummaryTotals {
  final int totalActualQty;
  final int totalPlanQty;
  final int bucketCount;

  /// `SUM(available_for_dispatch_qty)` over the filtered bucket set.
  /// Drives the "Remaining" tile on the totals banner.
  final int totalAvailableForDispatchQty;

  const DplProductionSummaryTotals({
    this.totalActualQty = 0,
    this.totalPlanQty = 0,
    this.bucketCount = 0,
    this.totalAvailableForDispatchQty = 0,
  });

  factory DplProductionSummaryTotals.fromJson(Map<String, dynamic> json) {
    return DplProductionSummaryTotals(
      totalActualQty: parseIntOr(
        json['total_actual_qty'] ?? json['totalActualQty'],
      ),
      totalPlanQty: parseIntOr(
        json['total_plan_qty'] ?? json['totalPlanQty'],
      ),
      bucketCount: parseIntOr(json['bucket_count'] ?? json['bucketCount']),
      totalAvailableForDispatchQty: parseIntOr(
        json['total_available_for_dispatch_qty'] ??
            json['totalAvailableForDispatchQty'],
      ),
    );
  }
}

/// Combined payload returned by `GET /manager/production-summary` — a
/// page of items plus its pagination block and the rolling totals over
/// the filtered set.
class DplProductionSummaryPage {
  final List<DplProductionSummary> items;
  final int page;
  final int limit;
  final int total;
  final int totalPages;
  final DplProductionSummaryTotals totals;

  const DplProductionSummaryPage({
    required this.items,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
    required this.totals,
  });

  factory DplProductionSummaryPage.empty() => const DplProductionSummaryPage(
        items: [],
        page: 1,
        limit: 50,
        total: 0,
        totalPages: 0,
        totals: DplProductionSummaryTotals(),
      );

  bool get hasMore => page < totalPages;

  factory DplProductionSummaryPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) =>
                DplProductionSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplProductionSummary>[];

    final rawPagination = json['pagination'];
    final pagination = rawPagination is Map
        ? Map<String, dynamic>.from(rawPagination)
        : const <String, dynamic>{};

    final rawTotals = json['totals'];
    final totals = rawTotals is Map
        ? DplProductionSummaryTotals.fromJson(
            Map<String, dynamic>.from(rawTotals),
          )
        : const DplProductionSummaryTotals();

    return DplProductionSummaryPage(
      items: items,
      page: parseIntOr(pagination['page'], 1),
      limit: parseIntOr(pagination['limit'], items.length),
      total: parseIntOr(pagination['total'], items.length),
      totalPages: parseIntOr(pagination['totalPages'] ?? pagination['total_pages']),
      totals: totals,
    );
  }
}
