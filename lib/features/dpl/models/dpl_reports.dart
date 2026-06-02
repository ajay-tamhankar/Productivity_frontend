import '_json_helpers.dart';

/// Plan vs Actual report — per machine, plus an overall total.
class DplPlanVsActualReport {
  final List<DplPlanVsActualRow> rows;
  final int totalPlan;
  final int totalActual;
  final double completionPct;

  const DplPlanVsActualReport({
    required this.rows,
    required this.totalPlan,
    required this.totalActual,
    required this.completionPct,
  });

  factory DplPlanVsActualReport.fromJson(Map<String, dynamic> json) {
    final raw = json['rows'] ?? json['data'] ?? json['items'];
    final rows = raw is List
        ? raw
            .whereType<Map>()
            .map((e) =>
                DplPlanVsActualRow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplPlanVsActualRow>[];

    int totalPlan = parseIntOr(json['total_plan'] ?? json['totalPlan'], -1);
    int totalActual =
        parseIntOr(json['total_actual'] ?? json['totalActual'], -1);
    if (totalPlan < 0) {
      totalPlan = rows.fold(0, (a, r) => a + r.planQty);
    }
    if (totalActual < 0) {
      totalActual = rows.fold(0, (a, r) => a + r.actualQty);
    }
    final pct = totalPlan == 0
        ? 0.0
        : (totalActual / totalPlan).clamp(0.0, 1.0).toDouble();

    return DplPlanVsActualReport(
      rows: rows,
      totalPlan: totalPlan,
      totalActual: totalActual,
      completionPct: pct,
    );
  }

  factory DplPlanVsActualReport.empty() => const DplPlanVsActualReport(
        rows: [],
        totalPlan: 0,
        totalActual: 0,
        completionPct: 0,
      );
}

class DplPlanVsActualRow {
  final int machineId;
  final String machineName;
  final int planQty;
  final int actualQty;
  /// Present only when the report was requested with `?group_by=day`.
  final DateTime? planDate;
  /// Present only when the report was requested with `?group_by=shift`.
  final int? shiftId;
  final String? shiftCode;

  const DplPlanVsActualRow({
    required this.machineId,
    required this.machineName,
    required this.planQty,
    required this.actualQty,
    this.planDate,
    this.shiftId,
    this.shiftCode,
  });

  factory DplPlanVsActualRow.fromJson(Map<String, dynamic> json) {
    return DplPlanVsActualRow(
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      machineName:
          parseStringOr(json['machine_name'] ?? json['machineName']),
      planQty: parseIntOr(json['plan_qty'] ?? json['planQty']),
      actualQty: parseIntOr(json['actual_qty'] ?? json['actualQty']),
      planDate: parseDateTimeOrNull(json['plan_date'] ?? json['planDate']),
      shiftId: parseIntOrNull(json['shift_id'] ?? json['shiftId']),
      shiftCode: parseStringOr(
        json['shift_code'] ?? json['shiftCode'],
      ).isEmpty
          ? null
          : parseStringOr(json['shift_code'] ?? json['shiftCode']),
    );
  }

  double get completionPct =>
      planQty <= 0 ? 0 : (actualQty / planQty).clamp(0.0, 1.0);
}

/// Downtime Pareto: each row is one reason + its total minutes.
class DplDowntimeReport {
  final List<DplDowntimeRow> rows;

  const DplDowntimeReport({required this.rows});

  factory DplDowntimeReport.fromJson(Map<String, dynamic> json) {
    final raw = json['rows'] ?? json['data'] ?? json['items'];
    final rows = raw is List
        ? raw
            .whereType<Map>()
            .map((e) =>
                DplDowntimeRow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplDowntimeRow>[];
    return DplDowntimeReport(rows: rows);
  }

  factory DplDowntimeReport.empty() =>
      const DplDowntimeReport(rows: <DplDowntimeRow>[]);

  bool get isEmpty => rows.isEmpty;
}

class DplDowntimeRow {
  final int reasonId;
  final String reasonName;
  final String category;
  final int totalMinutes;
  final int occurrences;
  final double avgMinutes;
  /// Present only when the report was requested with `?group_by=day`.
  final DateTime? bucketDate;

  const DplDowntimeRow({
    required this.reasonId,
    required this.reasonName,
    required this.category,
    required this.totalMinutes,
    required this.occurrences,
    this.avgMinutes = 0,
    this.bucketDate,
  });

  factory DplDowntimeRow.fromJson(Map<String, dynamic> json) {
    return DplDowntimeRow(
      reasonId: parseIntOr(json['reason_id'] ?? json['reasonId']),
      reasonName:
          parseStringOr(json['reason_name'] ?? json['reasonName'] ?? json['name']),
      category: parseStringOr(json['category'], 'unplanned'),
      totalMinutes:
          parseIntOr(json['total_minutes'] ?? json['totalMinutes']),
      // Backend uses `event_count`; older shapes used `occurrences` / `count`.
      occurrences: parseIntOr(
        json['event_count'] ??
            json['eventCount'] ??
            json['occurrences'] ??
            json['count'],
      ),
      avgMinutes: parseDoubleOr(
        json['avg_minutes'] ?? json['avgMinutes'],
      ),
      bucketDate: parseDateTimeOrNull(
        json['day'] ??
            json['date'] ??
            json['bucket_date'] ??
            json['bucketDate'] ??
            json['plan_date'] ??
            json['planDate'],
      ),
    );
  }
}

class DplSupervisorPerformanceReport {
  final List<DplSupervisorPerformanceRow> rows;

  const DplSupervisorPerformanceReport({required this.rows});

  factory DplSupervisorPerformanceReport.fromJson(Map<String, dynamic> json) {
    final raw = json['rows'] ?? json['data'] ?? json['items'];
    final rows = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => DplSupervisorPerformanceRow.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <DplSupervisorPerformanceRow>[];
    return DplSupervisorPerformanceReport(rows: rows);
  }

  factory DplSupervisorPerformanceReport.empty() =>
      const DplSupervisorPerformanceReport(rows: []);
}

class DplSupervisorPerformanceRow {
  final int supervisorUserId;
  final String supervisorName;
  final int totalPlan;
  final int totalActual;
  final double completionPct;
  final int plansHandled;

  const DplSupervisorPerformanceRow({
    required this.supervisorUserId,
    required this.supervisorName,
    required this.totalPlan,
    required this.totalActual,
    required this.completionPct,
    required this.plansHandled,
  });

  factory DplSupervisorPerformanceRow.fromJson(Map<String, dynamic> json) {
    final totalPlan = parseIntOr(json['total_plan'] ?? json['totalPlan']);
    final totalActual =
        parseIntOr(json['total_actual'] ?? json['totalActual']);
    double pct = parseDoubleOr(
      json['completion_pct'] ?? json['completionPct'],
      -1,
    );
    if (pct < 0) {
      pct = totalPlan <= 0 ? 0 : totalActual / totalPlan;
    }
    if (pct > 1) pct = pct / 100;
    pct = pct.clamp(0.0, 1.0).toDouble();

    return DplSupervisorPerformanceRow(
      supervisorUserId: parseIntOr(
        json['supervisor_user_id'] ?? json['supervisorUserId'],
      ),
      supervisorName:
          parseStringOr(json['supervisor_name'] ?? json['supervisorName']),
      totalPlan: totalPlan,
      totalActual: totalActual,
      completionPct: pct,
      plansHandled: parseIntOr(json['plans_handled'] ?? json['plansHandled']),
    );
  }
}

class DplPartWiseReport {
  final List<DplPartWiseRow> rows;

  const DplPartWiseReport({required this.rows});

  factory DplPartWiseReport.fromJson(Map<String, dynamic> json) {
    final raw = json['rows'] ?? json['data'] ?? json['items'];
    final rows = raw is List
        ? raw
            .whereType<Map>()
            .map((e) =>
                DplPartWiseRow.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : <DplPartWiseRow>[];
    return DplPartWiseReport(rows: rows);
  }

  factory DplPartWiseReport.empty() => const DplPartWiseReport(rows: []);
}

class DplPartWiseRow {
  final int partId;
  final String partNumber;
  final String partDescription;
  final int totalPlan;
  final int totalActual;

  const DplPartWiseRow({
    required this.partId,
    required this.partNumber,
    required this.partDescription,
    required this.totalPlan,
    required this.totalActual,
  });

  factory DplPartWiseRow.fromJson(Map<String, dynamic> json) {
    return DplPartWiseRow(
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      partNumber: parseStringOr(json['part_number'] ?? json['partNumber']),
      partDescription:
          parseStringOr(json['part_description'] ?? json['partDescription']),
      totalPlan: parseIntOr(json['total_plan'] ?? json['totalPlan']),
      totalActual: parseIntOr(json['total_actual'] ?? json['totalActual']),
    );
  }

  double get completionPct =>
      totalPlan <= 0 ? 0 : (totalActual / totalPlan).clamp(0.0, 1.0);
}
