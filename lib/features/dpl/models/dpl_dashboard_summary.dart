import '_json_helpers.dart';

class DplDashboardSummary {
  final DateTime date;
  final int totalPlanQty;
  final int totalActualQty;
  final double completionPct;
  final List<DplMachineSummary> machines;

  const DplDashboardSummary({
    required this.date,
    required this.totalPlanQty,
    required this.totalActualQty,
    required this.completionPct,
    required this.machines,
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

    // Backend wraps daily totals under a `totals` object:
    //   { plan: N, actual: N, completion_pct: 0..1 }
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

    return DplDashboardSummary(
      date: parseDateTimeOrNull(json['date']) ?? DateTime.now(),
      totalPlanQty: totalPlan,
      totalActualQty: totalActual,
      completionPct: pct,
      machines: machines,
    );
  }

  factory DplDashboardSummary.empty(DateTime date) => DplDashboardSummary(
        date: date,
        totalPlanQty: 0,
        totalActualQty: 0,
        completionPct: 0,
        machines: const [],
      );
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

  const DplMachineSummary({
    required this.machineId,
    required this.machineName,
    required this.status,
    required this.planQty,
    required this.actualQty,
    required this.completionPct,
    required this.supervisorName,
    this.planId,
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
    );
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
