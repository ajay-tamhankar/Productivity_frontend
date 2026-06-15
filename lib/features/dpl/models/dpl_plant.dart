import '_json_helpers.dart';

/// One machine inside a plant, as returned in the `machines[]` block of
/// `GET /plants`. Same id/name/code shape `dpl_machines` exposes
/// elsewhere — just embedded under the plant for one-shot loading.
///
/// Backend may leave `name` or `code` null when the master row hasn't
/// been filled in yet (e.g. machine 10 in the current Sanand JIT
/// dataset). The UI falls back to `Machine #$id` via [label] in that
/// case, so the dropdown never renders an empty entry.
class DplPlantMachine {
  final int id;
  final String name;
  final String code;

  const DplPlantMachine({
    required this.id,
    this.name = '',
    this.code = '',
  });

  factory DplPlantMachine.fromJson(Map<String, dynamic> json) {
    return DplPlantMachine(
      id: parseIntOr(json['id']),
      name: parseStringOr(json['name']),
      code: parseStringOr(json['code']),
    );
  }

  /// User-facing label — name → code → `Machine #id` fallback chain so
  /// every machine renders something even if master data is missing.
  String get label {
    final n = name.trim();
    if (n.isNotEmpty) return n;
    final c = code.trim();
    if (c.isNotEmpty) return c;
    return 'Machine #$id';
  }
}

/// Per-plant aggregate stats, returned in the `stats` block of
/// `GET /plants`. Computed server-side as the same SUM aggregates the
/// production-summary `totals` block uses, scoped per plant via
/// `machine_id IN (plant.machine_ids)`. Zero-filled (never null) when
/// the plant has no production yet.
///
/// Splits into three families:
///   * **Production** — `totalActualQty`, `totalPlanQty`,
///     `completedItems`, `inProgressItems`, `pendingItems` (item
///     counts) — what supervisors have produced against plans.
///   * **Available** — `availableForDispatchQty` — what's still
///     bookable (actual minus committed slip qty).
///   * **Dispatch slip qty** — `pendingQaQty`, `pendingPdiQty`,
///     `approvedQty`, `rejectedQty`, `dispatchedQty` — qty broken
///     down by slip status across the plant's slips. Backend also
///     ships two convenience aggregates: `pendingQty = pending_qa_qty
///     + pending_pdi_qty` and `completedQty = approved_qty +
///     dispatched_qty`, used by the FE to surface "waiting on
///     approval" + "made it through" without doing the addition
///     ourselves.
///
/// All values are lifetime counts — backend doesn't date-scope these.
class DplPlantStats {
  final int totalActualQty;
  final int totalPlanQty;
  final int completedItems;
  final int inProgressItems;
  final int pendingItems;
  final int availableForDispatchQty;

  // Dispatch slip qty rollups (added 2026-06-15 backend update).
  final int pendingQaQty;
  final int pendingPdiQty;
  final int approvedQty;
  final int rejectedQty;
  final int dispatchedQty;

  /// `pendingQaQty + pendingPdiQty` — slips currently waiting on
  /// QA or PDI approval. Surfaced as "X NOS waiting on approval"
  /// on the plant card.
  final int pendingQty;

  /// `approvedQty + dispatchedQty` — slips that made it through
  /// QA → PDI (regardless of whether they've physically shipped yet).
  final int completedQty;

  const DplPlantStats({
    this.totalActualQty = 0,
    this.totalPlanQty = 0,
    this.completedItems = 0,
    this.inProgressItems = 0,
    this.pendingItems = 0,
    this.availableForDispatchQty = 0,
    this.pendingQaQty = 0,
    this.pendingPdiQty = 0,
    this.approvedQty = 0,
    this.rejectedQty = 0,
    this.dispatchedQty = 0,
    this.pendingQty = 0,
    this.completedQty = 0,
  });

  factory DplPlantStats.zero() => const DplPlantStats();

  factory DplPlantStats.fromJson(Map<String, dynamic> json) {
    return DplPlantStats(
      totalActualQty:
          parseIntOr(json['total_actual_qty'] ?? json['totalActualQty']),
      totalPlanQty:
          parseIntOr(json['total_plan_qty'] ?? json['totalPlanQty']),
      completedItems:
          parseIntOr(json['completed_items'] ?? json['completedItems']),
      inProgressItems:
          parseIntOr(json['in_progress_items'] ?? json['inProgressItems']),
      pendingItems:
          parseIntOr(json['pending_items'] ?? json['pendingItems']),
      availableForDispatchQty: parseIntOr(
        json['available_for_dispatch_qty'] ??
            json['availableForDispatchQty'],
      ),
      pendingQaQty:
          parseIntOr(json['pending_qa_qty'] ?? json['pendingQaQty']),
      pendingPdiQty:
          parseIntOr(json['pending_pdi_qty'] ?? json['pendingPdiQty']),
      approvedQty: parseIntOr(json['approved_qty'] ?? json['approvedQty']),
      rejectedQty: parseIntOr(json['rejected_qty'] ?? json['rejectedQty']),
      dispatchedQty:
          parseIntOr(json['dispatched_qty'] ?? json['dispatchedQty']),
      pendingQty: parseIntOr(json['pending_qty'] ?? json['pendingQty']),
      completedQty:
          parseIntOr(json['completed_qty'] ?? json['completedQty']),
    );
  }

  /// True when the plant has any slip activity at all — used by the
  /// plant card to decide whether to render the dispatch-side stats
  /// row or hide it for cleaner empty-state plants.
  bool get hasAnyDispatchActivity =>
      pendingQty > 0 ||
      approvedQty > 0 ||
      dispatchedQty > 0 ||
      rejectedQty > 0;
}

/// One DPL plant — Nexon EV / TML PV / MG Motors today, hardcoded
/// server-side. Each plant owns a fixed list of machines, the parts
/// produced on those machines roll up under it, and a dispatch slip
/// is scoped to a single plant.
///
/// Used in two contexts:
///   1. Top-level entity in `GET /plants` — full payload with
///      `machineIds`, `machines[]`, and `stats`.
///   2. Embedded reference on a slip (`slip.plant`) — minimal payload
///      with just `code` + `name`. The other fields default to empty
///      so the same model handles both shapes cleanly.
class DplPlant {
  /// URL-safe stable identifier (e.g. `NEXON_EV`). Backend enforces
  /// `/^[A-Z0-9_]+$/`.
  final String code;

  /// Human-readable display name (e.g. "Nexon EV").
  final String name;

  /// Machine ids belonging to this plant — kept for back-compat with
  /// the pre-enrichment `GET /plants` shape. New code should prefer
  /// [machines] which carries names too.
  final List<int> machineIds;

  /// Full machine list with name + code, populated by the enriched
  /// `GET /plants` endpoint. Empty when embedded on a slip.
  final List<DplPlantMachine> machines;

  /// Per-plant aggregate production stats. `DplPlantStats.zero()` when
  /// embedded on a slip or for plants with no production yet.
  final DplPlantStats stats;

  const DplPlant({
    required this.code,
    required this.name,
    this.machineIds = const [],
    this.machines = const [],
    this.stats = const DplPlantStats(),
  });

  factory DplPlant.fromJson(Map<String, dynamic> json) {
    final rawIds = json['machine_ids'] ?? json['machineIds'];
    final ids = rawIds is List
        ? rawIds
            .map((e) => parseIntOrNull(e))
            .whereType<int>()
            .toList(growable: false)
        : const <int>[];

    final rawMachines = json['machines'];
    final parsedMachines = rawMachines is List
        ? rawMachines
            .whereType<Map>()
            .map((e) =>
                DplPlantMachine.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <DplPlantMachine>[];

    final rawStats = json['stats'];
    final parsedStats = rawStats is Map
        ? DplPlantStats.fromJson(Map<String, dynamic>.from(rawStats))
        : DplPlantStats.zero();

    return DplPlant(
      code: parseStringOr(json['code']),
      name: parseStringOr(json['name']),
      machineIds: ids,
      machines: parsedMachines,
      stats: parsedStats,
    );
  }

  /// Total machines in the plant. Prefers the enriched `machines[]`
  /// list when present; falls back to `machineIds.length` for the
  /// pre-enrichment shape.
  int get machineCount =>
      machines.isNotEmpty ? machines.length : machineIds.length;
}
