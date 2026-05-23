import '_json_helpers.dart';

class DplDashboardSummary {
  final DateTime date;
  final int totalPlanQty;
  final int totalActualQty;
  final double completionPct;

  /// Sum of resolved downtime events (i.e. closed with `end_time`)
  /// that started on [date]. Backend convention matches
  /// `/reports/downtime` so numbers stay consistent across surfaces.
  final int totalDowntimeMinutes;

  /// Month-to-date roll-up for the same plant the dashboard is
  /// scoped to. Backend bundles this in the same response so the
  /// client doesn't have to fire a second `/reports/dpl-chart` call
  /// just to show the MTD card.
  final DplDashboardMtd? mtd;

  final List<DplMachineSummary> machines;

  /// Per-shift rollup for [date] computed by the backend
  /// (`shifts[]` in the response). Each entry is the totals for one
  /// shift; a `shift_id: null` bucket can appear for legacy plans
  /// without an assigned shift.
  final List<DplDashboardShiftRollup> shifts;

  const DplDashboardSummary({
    required this.date,
    required this.totalPlanQty,
    required this.totalActualQty,
    required this.completionPct,
    required this.machines,
    this.shifts = const [],
    this.totalDowntimeMinutes = 0,
    this.mtd,
  });

  factory DplDashboardSummary.fromJson(Map<String, dynamic> json) {
    final rawMachines = json['machines'];
    final machines = rawMachines is List
        ? rawMachines
            .whereType<Map>()
            .map((e) =>
                DplMachineSummary.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplMachineSummary>[];

    final rawShifts = json['shifts'];
    final shifts = rawShifts is List
        ? rawShifts
            .whereType<Map>()
            .map((e) =>
                DplDashboardShiftRollup.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplDashboardShiftRollup>[];

    // Backend wraps daily totals under a `totals` object:
    //   { plan: N, actual: N, completion_pct: 0..100, downtime_minutes: N }
    Map<String, dynamic> totals = const {};
    final rawTotals = json['totals'];
    if (rawTotals is Map) {
      totals = Map<String, dynamic>.from(rawTotals);
    }

    final totalPlan = parseIntOr(
      totals['plan'] ??
          totals['total_plan_qty'] ??
          json['total_plan_qty'] ??
          json['totalPlanQty'],
    );
    final totalActual = parseIntOr(
      totals['actual'] ??
          totals['total_actual_qty'] ??
          json['total_actual_qty'] ??
          json['totalActualQty'],
    );

    double pct = parseDoubleOr(
      totals['completion_pct'] ??
          totals['completionPct'] ??
          json['completion_pct'] ??
          json['completionPct'],
      -1,
    );
    if (pct < 0) {
      pct = totalPlan <= 0 ? 0 : (totalActual / totalPlan);
    }
    if (pct > 1) pct = pct / 100;
    pct = pct.clamp(0.0, 1.0).toDouble();

    final downtimeMin = parseIntOr(
      totals['downtime_minutes'] ?? totals['downtimeMinutes'],
    );

    DplDashboardMtd? mtd;
    final rawMtd = json['mtd'];
    if (rawMtd is Map) {
      mtd = DplDashboardMtd.fromJson(Map<String, dynamic>.from(rawMtd));
    }

    return DplDashboardSummary(
      date: parseDateTimeOrNull(json['date']) ?? DateTime.now(),
      totalPlanQty: totalPlan,
      totalActualQty: totalActual,
      completionPct: pct,
      totalDowntimeMinutes: downtimeMin,
      mtd: mtd,
      machines: machines,
      shifts: shifts,
    );
  }

  factory DplDashboardSummary.empty(DateTime date) => DplDashboardSummary(
        date: date,
        totalPlanQty: 0,
        totalActualQty: 0,
        completionPct: 0,
        totalDowntimeMinutes: 0,
        machines: const [],
        shifts: const [],
      );
}

/// One row of the `shifts[]` rollup the backend returns alongside
/// `machines[]`. `shiftId` (and its code/name) may be `null` for a
/// legacy bucket of plans that don't have a per-plan shift assigned.
class DplDashboardShiftRollup {
  final int? shiftId;
  final String shiftCode;
  final String shiftName;
  final int planCount;
  final int planQty;
  final int actualQty;
  final double completionPct;

  const DplDashboardShiftRollup({
    this.shiftId,
    this.shiftCode = '',
    this.shiftName = '',
    this.planCount = 0,
    this.planQty = 0,
    this.actualQty = 0,
    this.completionPct = 0,
  });

  factory DplDashboardShiftRollup.fromJson(Map<String, dynamic> json) {
    final plan = parseIntOr(json['plan'] ?? json['plan_qty']);
    final actual = parseIntOr(json['actual'] ?? json['actual_qty']);
    double pct = parseDoubleOr(
      json['completion_pct'] ?? json['completionPct'],
      -1,
    );
    if (pct < 0) {
      pct = plan <= 0 ? 0 : (actual / plan);
    }
    if (pct > 1) pct = pct / 100;
    pct = pct.clamp(0.0, 1.0).toDouble();

    return DplDashboardShiftRollup(
      shiftId: parseIntOrNull(json['shift_id'] ?? json['shiftId']),
      shiftCode: parseStringOr(json['shift_code'] ?? json['shiftCode']),
      shiftName: parseStringOr(json['shift_name'] ?? json['shiftName']),
      planCount: parseIntOr(json['plan_count'] ?? json['planCount']),
      planQty: plan,
      actualQty: actual,
      completionPct: pct,
    );
  }

  /// Compact display label for the chip / strip — prefers
  /// `shiftName`, falls back to the code, then to "Unassigned" for the
  /// `shift_id=null` legacy bucket.
  String get displayLabel {
    if (shiftName.isNotEmpty) return shiftName;
    if (shiftCode.isNotEmpty) return 'Shift $shiftCode';
    return 'Unassigned';
  }
}

/// Month-to-date roll-up bundled inside the dashboard response.
class DplDashboardMtd {
  final DateTime? from;
  final DateTime? to;
  final int planQty;
  final int actualQty;
  final double completionPct;
  final int downtimeMinutes;

  const DplDashboardMtd({
    this.from,
    this.to,
    this.planQty = 0,
    this.actualQty = 0,
    this.completionPct = 0,
    this.downtimeMinutes = 0,
  });

  factory DplDashboardMtd.fromJson(Map<String, dynamic> json) {
    final plan = parseIntOr(json['plan'] ?? json['plan_qty']);
    final actual = parseIntOr(json['actual'] ?? json['actual_qty']);
    double pct = parseDoubleOr(
      json['completion_pct'] ?? json['completionPct'],
      -1,
    );
    if (pct < 0) {
      pct = plan <= 0 ? 0 : (actual / plan);
    }
    if (pct > 1) pct = pct / 100;
    pct = pct.clamp(0.0, 1.0).toDouble();

    return DplDashboardMtd(
      from: parseDateTimeOrNull(json['from']),
      to: parseDateTimeOrNull(json['to']),
      planQty: plan,
      actualQty: actual,
      completionPct: pct,
      downtimeMinutes: parseIntOr(
        json['downtime_minutes'] ?? json['downtimeMinutes'],
      ),
    );
  }
}

class DplMachineSummary {
  final int? planId;
  final int machineId;
  final String machineName;
  /// pending / in_progress / completed / locked  (drives the status badge)
  final String status;
  final int planQty;
  final int actualQty;
  final double completionPct;
  final String supervisorName;

  /// Per-plan shift the backend now includes on each machine row. May
  /// be `null` for legacy plans that have no shift assigned.
  final int? shiftId;
  final String shiftCode;
  final String shiftName;

  const DplMachineSummary({
    required this.machineId,
    required this.machineName,
    required this.status,
    required this.planQty,
    required this.actualQty,
    required this.completionPct,
    required this.supervisorName,
    this.planId,
    this.shiftId,
    this.shiftCode = '',
    this.shiftName = '',
  });

  factory DplMachineSummary.fromJson(Map<String, dynamic> json) {
    final planQty = parseIntOr(
      json['plan_qty'] ?? json['planQty'] ?? json['plan'],
    );
    final actualQty = parseIntOr(
      json['actual_qty'] ?? json['actualQty'] ?? json['actual'],
    );

    double pct = parseDoubleOr(
      json['completion_pct'] ?? json['completionPct'],
      -1,
    );
    if (pct < 0) {
      pct = planQty <= 0 ? 0 : (actualQty / planQty);
    }
    if (pct > 1) pct = pct / 100;
    pct = pct.clamp(0.0, 1.0).toDouble();

    return DplMachineSummary(
      planId: parseIntOrNull(json['plan_id'] ?? json['planId']),
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      // Accept both the master-style `machine_name` and the dashboard
      // shape which may inline a plain `name`.
      machineName: parseStringOr(
        json['machine_name'] ?? json['machineName'] ?? json['name'],
      ),
      status: parseStringOr(json['status'], 'pending').toLowerCase(),
      planQty: planQty,
      actualQty: actualQty,
      completionPct: pct,
      supervisorName: parseStringOr(
        json['supervisor_name'] ?? json['supervisorName'],
      ),
      shiftId: parseIntOrNull(json['shift_id'] ?? json['shiftId']),
      shiftCode: parseStringOr(json['shift_code'] ?? json['shiftCode']),
      shiftName: parseStringOr(json['shift_name'] ?? json['shiftName']),
    );
  }

  /// Short display label for the on-card chip — prefers the short
  /// `shift_code` (e.g. "A"), falls back to the full name.
  String get shiftLabel {
    if (shiftCode.isNotEmpty) return 'Shift $shiftCode';
    if (shiftName.isNotEmpty) return shiftName;
    return '';
  }
}

/// A single alert tile shown on the Manager dashboard.
///
/// The backend exposes alerts as two grouped buckets:
///   { plans_behind: [...], active_downtimes: [...], totals: {...} }
/// — we flatten them to a single [DplAlert] stream so the UI can render
/// them uniformly.
class DplAlert {
  final String severity;
  final String title;
  final String message;
  final int? planId;
  final int? machineId;

  const DplAlert({
    required this.severity,
    required this.title,
    required this.message,
    this.planId,
    this.machineId,
  });

  factory DplAlert.fromJson(Map<String, dynamic> json) {
    return DplAlert(
      severity: parseStringOr(json['severity'], 'info').toLowerCase(),
      title: parseStringOr(json['title']),
      message: parseStringOr(json['message']),
      planId: parseIntOrNull(json['plan_id'] ?? json['planId']),
      machineId: parseIntOrNull(json['machine_id'] ?? json['machineId']),
    );
  }

  /// Builds an alert tile from a "plan behind" row.
  factory DplAlert.fromPlanBehind(Map<String, dynamic> json) {
    final machine =
        parseStringOr(json['machine_name'] ?? json['machineName']);
    final plan = parseIntOr(json['plan_qty'] ?? json['planQty']);
    final actual = parseIntOr(json['actual_qty'] ?? json['actualQty']);
    final pct = plan <= 0 ? 0 : ((actual / plan) * 100).round();
    return DplAlert(
      severity: 'warning',
      title: machine.isEmpty ? 'Plan behind schedule' : 'Behind on $machine',
      message: 'Plan $plan, actual $actual ($pct%).',
      planId: parseIntOrNull(json['plan_id'] ?? json['planId']),
      machineId: parseIntOrNull(json['machine_id'] ?? json['machineId']),
    );
  }

  /// Builds an alert tile from an "active downtime" row.
  factory DplAlert.fromActiveDowntime(Map<String, dynamic> json) {
    final machine =
        parseStringOr(json['machine_name'] ?? json['machineName']);
    final reason =
        parseStringOr(json['reason_name'] ?? json['reasonName']);
    final minutes =
        parseIntOr(json['duration_minutes'] ?? json['minutes'] ?? json['duration']);
    return DplAlert(
      severity: 'critical',
      title: machine.isEmpty
          ? 'Active downtime'
          : 'Downtime on $machine',
      message: reason.isEmpty
          ? 'Active for $minutes min.'
          : '$reason — $minutes min.',
      machineId: parseIntOrNull(json['machine_id'] ?? json['machineId']),
    );
  }
}
