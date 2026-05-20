import '_json_helpers.dart';

/// Response of `POST /supervisor/plans/:planId/items/:itemId/start`.
class StartItemResponse {
  final int itemId;
  final int planId;
  final DateTime startTime;
  final String status;

  const StartItemResponse({
    required this.itemId,
    required this.planId,
    required this.startTime,
    required this.status,
  });

  factory StartItemResponse.fromJson(Map<String, dynamic> json) {
    return StartItemResponse(
      itemId: parseIntOr(json['item_id'] ?? json['itemId']),
      planId: parseIntOr(json['plan_id'] ?? json['planId']),
      startTime:
          parseDateTimeOrNull(json['start_time'] ?? json['startTime']) ??
              DateTime.now().toUtc(),
      status: parseStringOr(json['status'], 'in_progress').toLowerCase(),
    );
  }
}

/// Response of `POST /supervisor/plans/:planId/items/:itemId/stop`.
class StopItemResponse {
  final int itemId;
  final DateTime startTime;
  final DateTime endTime;
  final int actualQty;
  final int planQty;
  final int durationMinutes;
  final int totalPausedMinutes;
  final int netDurationMinutes;
  final String status;
  final bool planCompleted;

  const StopItemResponse({
    required this.itemId,
    required this.startTime,
    required this.endTime,
    required this.actualQty,
    required this.planQty,
    required this.durationMinutes,
    required this.totalPausedMinutes,
    required this.netDurationMinutes,
    required this.status,
    required this.planCompleted,
  });

  factory StopItemResponse.fromJson(Map<String, dynamic> json) {
    return StopItemResponse(
      itemId: parseIntOr(json['item_id'] ?? json['itemId']),
      startTime:
          parseDateTimeOrNull(json['start_time'] ?? json['startTime']) ??
              DateTime.now().toUtc(),
      endTime: parseDateTimeOrNull(json['end_time'] ?? json['endTime']) ??
          DateTime.now().toUtc(),
      actualQty: parseIntOr(json['actual_qty'] ?? json['actualQty']),
      planQty: parseIntOr(json['plan_qty'] ?? json['planQty']),
      durationMinutes:
          parseIntOr(json['duration_minutes'] ?? json['durationMinutes']),
      totalPausedMinutes: parseIntOr(
        json['total_paused_minutes'] ?? json['totalPausedMinutes'],
      ),
      netDurationMinutes: parseIntOr(
        json['net_duration_minutes'] ?? json['netDurationMinutes'],
      ),
      status: parseStringOr(json['status'], 'completed').toLowerCase(),
      planCompleted: json['plan_completed'] == true ||
          json['planCompleted'] == true,
    );
  }

  int get variance => actualQty - planQty;
}
