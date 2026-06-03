import '_json_helpers.dart';

/// Response of `GET /supervisor/today` — one supervisor's plan list for
/// the current shift, plus per-plan status snippets that drive the
/// dashboard tiles.
class SupervisorTodayResponse {
  final DateTime date;
  final String supervisorName;
  final List<SupervisorPlanSummary> plans;

  const SupervisorTodayResponse({
    required this.date,
    required this.supervisorName,
    required this.plans,
  });

  factory SupervisorTodayResponse.fromJson(Map<String, dynamic> json) {
    final raw = json['plans'];
    final plans = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => SupervisorPlanSummary.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <SupervisorPlanSummary>[];
    return SupervisorTodayResponse(
      date: parseDateTimeOrNull(json['date']) ?? DateTime.now(),
      supervisorName:
          parseStringOr(json['supervisor_name'] ?? json['supervisorName']),
      plans: plans,
    );
  }

  factory SupervisorTodayResponse.empty(DateTime date) =>
      SupervisorTodayResponse(
        date: date,
        supervisorName: '',
        plans: const [],
      );
}

class SupervisorPlanSummary {
  final int id;
  final int machineId;
  final String machineName;
  final int totalPlanQty;
  final int totalActualQty;
  final double completionPct;
  final String status;
  final ActiveDowntime? activeDowntime;
  final int itemsPending;
  final int itemsInProgress;
  final int itemsCompleted;

  const SupervisorPlanSummary({
    required this.id,
    required this.machineId,
    required this.machineName,
    required this.totalPlanQty,
    required this.totalActualQty,
    required this.completionPct,
    required this.status,
    required this.itemsPending,
    required this.itemsInProgress,
    required this.itemsCompleted,
    this.activeDowntime,
  });

  factory SupervisorPlanSummary.fromJson(Map<String, dynamic> json) {
    final plan = parseIntOr(json['total_plan_qty'] ?? json['totalPlanQty']);
    final actual =
        parseIntOr(json['total_actual_qty'] ?? json['totalActualQty']);

    double pct = parseDoubleOr(
      json['completion_pct'] ?? json['completionPct'],
      -1,
    );
    if (pct < 0) pct = plan <= 0 ? 0 : actual / plan;
    if (pct > 1) pct = pct / 100;
    pct = pct.clamp(0.0, 1.0).toDouble();

    Map<String, dynamic> machineMap = const {};
    final rawMachine = json['machine'];
    if (rawMachine is Map) machineMap = Map<String, dynamic>.from(rawMachine);

    return SupervisorPlanSummary(
      id: parseIntOr(json['id'] ?? json['plan_id']),
      machineId: parseIntOr(
        json['machine_id'] ?? json['machineId'] ?? machineMap['id'],
      ),
      machineName: parseStringOr(
        json['machine_name'] ??
            json['machineName'] ??
            machineMap['machine_name'] ??
            machineMap['name'],
      ),
      totalPlanQty: plan,
      totalActualQty: actual,
      completionPct: pct,
      status: parseStringOr(json['status'], 'pending').toLowerCase(),
      itemsPending:
          parseIntOr(json['items_pending'] ?? json['itemsPending']),
      itemsInProgress:
          parseIntOr(json['items_in_progress'] ?? json['itemsInProgress']),
      itemsCompleted:
          parseIntOr(json['items_completed'] ?? json['itemsCompleted']),
      activeDowntime: _parseActive(json['active_downtime'] ?? json['activeDowntime']),
    );
  }

  static ActiveDowntime? _parseActive(dynamic raw) {
    if (raw is! Map) return null;
    return ActiveDowntime.fromJson(Map<String, dynamic>.from(raw));
  }
}

class ActiveDowntime {
  final int id;
  final String reasonName;
  final DateTime startTime;
  final int? machineId;
  final String? machineName;
  final int? planId;
  final int? planItemId;
  final int? supervisorUserId;
  final String? supervisorName;
  final String? shiftCode;
  final String? category;

  const ActiveDowntime({
    required this.id,
    required this.reasonName,
    required this.startTime,
    this.machineId,
    this.machineName,
    this.planId,
    this.planItemId,
    this.supervisorUserId,
    this.supervisorName,
    this.shiftCode,
    this.category,
  });

  factory ActiveDowntime.fromJson(Map<String, dynamic> json) {
    String? strOrNull(dynamic raw) {
      if (raw == null) return null;
      final text = raw.toString().trim();
      return text.isEmpty ? null : text;
    }

    return ActiveDowntime(
      id: parseIntOr(json['id']),
      reasonName: parseStringOr(
        json['reason_name'] ?? json['reasonName'],
      ),
      startTime:
          parseDateTimeOrNull(json['start_time'] ?? json['startTime']) ??
              DateTime.now().toUtc(),
      machineId: parseIntOrNull(json['machine_id'] ?? json['machineId']),
      machineName: strOrNull(json['machine_name'] ?? json['machineName']),
      planId: parseIntOrNull(json['plan_id'] ?? json['planId']),
      planItemId:
          parseIntOrNull(json['plan_item_id'] ?? json['planItemId']),
      supervisorUserId: parseIntOrNull(
        json['supervisor_user_id'] ?? json['supervisorUserId'],
      ),
      supervisorName: strOrNull(
        json['supervisor_name'] ?? json['supervisorName'],
      ),
      shiftCode: strOrNull(json['shift_code'] ?? json['shiftCode']),
      category: strOrNull(json['category']),
    );
  }
}
