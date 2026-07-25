import '_json_helpers.dart';

/// One `(plant, machine, part)` row in the Dispatch **Plan vs Actual**
/// report.
///
///   * **Plan**   = Σ of the manager's trip-plan qty (bucketed by trip
///     date) — what was planned to ship.
///   * **Actual** = Σ of dispatched-slip item qty (bucketed by
///     `dispatched_at`) — what actually shipped.
///
/// Three period pairs are pre-aggregated by the backend:
///   * `today*`  — the current IST business day
///   * `mtd*`    — 1st of the current month → today (month-to-date)
///   * `till*`   — cumulative (all time to date)
class DplDispatchPlanActualRow {
  final String plantCode;
  final String plantName;
  final int machineId;
  final String machineName;
  final int partId;

  /// Short part-description code (e.g. "106D1").
  final String description;
  final String customerPn;
  final String partName;

  final int todayPlan;
  final int todayActual;
  final int mtdPlan;
  final int mtdActual;
  final int tillPlan;
  final int tillActual;

  const DplDispatchPlanActualRow({
    required this.partId,
    this.plantCode = '',
    this.plantName = '',
    this.machineId = 0,
    this.machineName = '',
    this.description = '',
    this.customerPn = '',
    this.partName = '',
    this.todayPlan = 0,
    this.todayActual = 0,
    this.mtdPlan = 0,
    this.mtdActual = 0,
    this.tillPlan = 0,
    this.tillActual = 0,
  });

  factory DplDispatchPlanActualRow.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> nested(String key) =>
        json[key] is Map ? Map<String, dynamic>.from(json[key] as Map) : const {};
    final part = nested('part');
    final machine = nested('machine');

    return DplDispatchPlanActualRow(
      plantCode: parseStringOr(json['plant_code'] ?? json['plantCode']),
      plantName: parseStringOr(json['plant_name'] ?? json['plantName']),
      machineId: parseIntOr(
        json['machine_id'] ?? json['machineId'] ?? machine['id'],
      ),
      machineName: parseStringOr(
        json['machine_name'] ??
            json['machineName'] ??
            machine['machine_name'] ??
            machine['name'],
      ),
      partId: parseIntOr(json['part_id'] ?? json['partId'] ?? part['id']),
      description: parseStringOr(json['description'] ?? part['description']),
      customerPn: parseStringOr(
        json['customer_pn'] ??
            json['customerPn'] ??
            part['customer_part_no'] ??
            part['customerPartNo'],
      ),
      partName: parseStringOr(
        json['part_name'] ?? json['partName'] ?? part['part_name'] ?? part['name'],
      ),
      todayPlan: parseIntOr(json['today_plan'] ?? json['todayPlan']),
      todayActual: parseIntOr(json['today_actual'] ?? json['todayActual']),
      mtdPlan: parseIntOr(json['mtd_plan'] ?? json['mtdPlan']),
      mtdActual: parseIntOr(json['mtd_actual'] ?? json['mtdActual']),
      tillPlan: parseIntOr(
        json['till_plan'] ?? json['tillPlan'] ?? json['till_date_plan'],
      ),
      tillActual: parseIntOr(
        json['till_actual'] ?? json['tillActual'] ?? json['till_date_actual'],
      ),
    );
  }

  int planFor(DplPvaPeriod p) => switch (p) {
        DplPvaPeriod.today => todayPlan,
        DplPvaPeriod.mtd => mtdPlan,
        DplPvaPeriod.till => tillPlan,
      };

  int actualFor(DplPvaPeriod p) => switch (p) {
        DplPvaPeriod.today => todayActual,
        DplPvaPeriod.mtd => mtdActual,
        DplPvaPeriod.till => tillActual,
      };
}

/// The three reporting windows shown as top cards.
enum DplPvaPeriod {
  today('Today'),
  mtd('MTD'),
  till('Till date');

  final String label;
  const DplPvaPeriod(this.label);
}

/// Full Dispatch Plan-vs-Actual report — one row per `(plant, machine,
/// part)`. The FE filters / sorts / re-aggregates these client-side, so
/// the endpoint just returns the whole breakdown for the org.
class DplDispatchPlanActualReport {
  final List<DplDispatchPlanActualRow> rows;

  const DplDispatchPlanActualReport({this.rows = const []});

  factory DplDispatchPlanActualReport.fromJson(Map<String, dynamic> json) {
    final raw = json['breakdown'] ?? json['rows'] ?? json['items'] ?? json['data'];
    final rows = raw is List
        ? raw
            .whereType<Map>()
            .map((e) =>
                DplDispatchPlanActualRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(growable: false)
        : const <DplDispatchPlanActualRow>[];
    return DplDispatchPlanActualReport(rows: rows);
  }

  bool get isEmpty => rows.isEmpty;

  /// Total plan across [rows] for [period].
  int planTotal(DplPvaPeriod period) =>
      rows.fold(0, (s, r) => s + r.planFor(period));

  /// Total actual across [rows] for [period].
  int actualTotal(DplPvaPeriod period) =>
      rows.fold(0, (s, r) => s + r.actualFor(period));
}
