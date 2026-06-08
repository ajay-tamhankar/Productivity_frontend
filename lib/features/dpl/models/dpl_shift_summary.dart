import '_json_helpers.dart';

class DplShiftSummary {
  final DateTime date;
  final String supervisorName;
  final List<DplShiftMachineSummary> machines;
  final DplShiftTotals totals;

  const DplShiftSummary({
    required this.date,
    required this.supervisorName,
    required this.machines,
    required this.totals,
  });

  factory DplShiftSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['machines'];
    final machines = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => DplShiftMachineSummary.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <DplShiftMachineSummary>[];

    final rawTotals = json['totals'];
    final totals = rawTotals is Map
        ? DplShiftTotals.fromJson(Map<String, dynamic>.from(rawTotals))
        : DplShiftTotals.empty();

    return DplShiftSummary(
      date: parseDateTimeOrNull(json['date']) ?? DateTime.now(),
      supervisorName: parseStringOr(
        json['supervisor_name'] ?? json['supervisorName'],
      ),
      machines: machines,
      totals: totals,
    );
  }

  factory DplShiftSummary.empty(DateTime date) => DplShiftSummary(
        date: date,
        supervisorName: '',
        machines: const [],
        totals: DplShiftTotals.empty(),
      );

  bool get hasIncompleteItems =>
      machines.any((m) => m.itemsIncomplete > 0);
}

class DplShiftMachineSummary {
  final int machineId;
  final String machineName;
  final int planQty;
  final int actualQty;
  final double completionPct;
  final int downtimeMinutes;
  final List<DplDowntimeReasonBreakdown> downtimeReasons;
  final int itemsTotal;
  final int itemsCompleted;
  final int itemsIncomplete;

  const DplShiftMachineSummary({
    required this.machineId,
    required this.machineName,
    required this.planQty,
    required this.actualQty,
    required this.completionPct,
    required this.downtimeMinutes,
    required this.downtimeReasons,
    required this.itemsTotal,
    required this.itemsCompleted,
    required this.itemsIncomplete,
  });

  factory DplShiftMachineSummary.fromJson(Map<String, dynamic> json) {
    final raw = json['downtime_reasons'] ?? json['downtimeReasons'];
    final reasons = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => DplDowntimeReasonBreakdown.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <DplDowntimeReasonBreakdown>[];

    final plan = parseIntOr(json['plan_qty'] ?? json['planQty']);
    final actual = parseIntOr(json['actual_qty'] ?? json['actualQty']);
    double pct = parseDoubleOr(
      json['completion_pct'] ?? json['completionPct'],
      -1,
    );
    if (pct < 0) pct = plan <= 0 ? 0 : actual / plan;
    if (pct > 1) pct = pct / 100;
    if (pct < 0) pct = 0;

    return DplShiftMachineSummary(
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      machineName: parseStringOr(
        json['machine_name'] ?? json['machineName'],
      ),
      planQty: plan,
      actualQty: actual,
      completionPct: pct,
      downtimeMinutes:
          parseIntOr(json['downtime_minutes'] ?? json['downtimeMinutes']),
      downtimeReasons: reasons,
      itemsTotal: parseIntOr(json['items_total'] ?? json['itemsTotal']),
      itemsCompleted:
          parseIntOr(json['items_completed'] ?? json['itemsCompleted']),
      itemsIncomplete:
          parseIntOr(json['items_incomplete'] ?? json['itemsIncomplete']),
    );
  }

  int get variance => actualQty - planQty;
}

class DplDowntimeReasonBreakdown {
  final String reasonName;
  final int minutes;

  const DplDowntimeReasonBreakdown({
    required this.reasonName,
    required this.minutes,
  });

  factory DplDowntimeReasonBreakdown.fromJson(Map<String, dynamic> json) {
    return DplDowntimeReasonBreakdown(
      reasonName: parseStringOr(
        json['reason_name'] ?? json['reasonName'] ?? json['name'],
      ),
      minutes: parseIntOr(json['minutes'] ?? json['duration_minutes']),
    );
  }
}

class DplShiftTotals {
  final int planQty;
  final int actualQty;
  final double completionPct;
  final int totalDowntimeMinutes;

  const DplShiftTotals({
    required this.planQty,
    required this.actualQty,
    required this.completionPct,
    required this.totalDowntimeMinutes,
  });

  factory DplShiftTotals.fromJson(Map<String, dynamic> json) {
    final plan = parseIntOr(json['plan_qty'] ?? json['planQty']);
    final actual = parseIntOr(json['actual_qty'] ?? json['actualQty']);
    double pct = parseDoubleOr(
      json['completion_pct'] ?? json['completionPct'],
      -1,
    );
    if (pct < 0) pct = plan <= 0 ? 0 : actual / plan;
    if (pct > 1) pct = pct / 100;
    if (pct < 0) pct = 0;

    return DplShiftTotals(
      planQty: plan,
      actualQty: actual,
      completionPct: pct,
      totalDowntimeMinutes: parseIntOr(
        json['total_downtime_minutes'] ?? json['totalDowntimeMinutes'],
      ),
    );
  }

  factory DplShiftTotals.empty() => const DplShiftTotals(
        planQty: 0,
        actualQty: 0,
        completionPct: 0,
        totalDowntimeMinutes: 0,
      );
}

/// Response of `POST /supervisor/shift/submit`.
class DplShiftSubmitResult {
  final int plansSubmitted;
  final int totalPlanQty;
  final int totalActualQty;
  final double completionPct;

  const DplShiftSubmitResult({
    required this.plansSubmitted,
    required this.totalPlanQty,
    required this.totalActualQty,
    required this.completionPct,
  });

  factory DplShiftSubmitResult.fromJson(Map<String, dynamic> json) {
    double pct = parseDoubleOr(
      json['completion_pct'] ?? json['completionPct'],
      0,
    );
    if (pct > 1) pct = pct / 100;
    if (pct < 0) pct = 0;
    return DplShiftSubmitResult(
      plansSubmitted:
          parseIntOr(json['plans_submitted'] ?? json['plansSubmitted']),
      totalPlanQty:
          parseIntOr(json['total_plan_qty'] ?? json['totalPlanQty']),
      totalActualQty:
          parseIntOr(json['total_actual_qty'] ?? json['totalActualQty']),
      completionPct: pct,
    );
  }
}
