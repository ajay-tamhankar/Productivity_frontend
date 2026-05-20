import 'dpl_downtime_event.dart';
import 'dpl_production_plan.dart';
import 'dpl_supervisor_today.dart';

/// Wraps the supervisor plan-detail response:
///   { "plan": {...}, "active_downtime": {...} | null, "downtime_history": [...] }
class DplSupervisorPlanDetail {
  final DplProductionPlan plan;
  final ActiveDowntime? activeDowntime;
  final List<DplDowntimeEvent> downtimeHistory;

  const DplSupervisorPlanDetail({
    required this.plan,
    required this.downtimeHistory,
    this.activeDowntime,
  });

  factory DplSupervisorPlanDetail.fromJson(Map<String, dynamic> json) {
    final rawPlan = json['plan'];
    if (rawPlan is! Map) {
      throw const FormatException('Missing plan in supervisor plan detail.');
    }

    final rawActive = json['active_downtime'] ?? json['activeDowntime'];
    final active = rawActive is Map
        ? ActiveDowntime.fromJson(Map<String, dynamic>.from(rawActive))
        : null;

    final rawHistory = json['downtime_history'] ?? json['downtimeHistory'];
    final history = rawHistory is List
        ? rawHistory
            .whereType<Map>()
            .map((e) => DplDowntimeEvent.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <DplDowntimeEvent>[];

    return DplSupervisorPlanDetail(
      plan: DplProductionPlan.fromJson(Map<String, dynamic>.from(rawPlan)),
      activeDowntime: active,
      downtimeHistory: history,
    );
  }
}
