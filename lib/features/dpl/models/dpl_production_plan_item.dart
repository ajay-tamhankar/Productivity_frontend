import '_json_helpers.dart';

class DplProductionPlanItem {
  final int id;
  final int planNo;
  final int partId;
  final String partNumber;
  final String partDescription;
  final String partName;
  final int planQty;
  final int sequence;
  /// pending / in_progress / completed (mirrors backend plan_item status)
  final String status;
  final int actualQty;
  final DateTime? startTime;
  final DateTime? endTime;
  /// Most recent downtime start (server-managed). Used by the supervisor
  /// execution screen to know an item is currently paused.
  final DateTime? pausedAt;
  /// Total minutes the item has spent paused across all downtimes.
  final int totalPausedMinutes;
  /// Shift the item ran in — server-derived from `start_time`. Null for
  /// items started before the column was added or never started.
  final int? shiftId;
  final String? shiftCode;
  final String? shiftName;
  final String? remarks;

  const DplProductionPlanItem({
    required this.id,
    required this.planNo,
    required this.partId,
    required this.planQty,
    required this.sequence,
    this.partNumber = '',
    this.partDescription = '',
    this.partName = '',
    this.status = 'pending',
    this.actualQty = 0,
    this.startTime,
    this.endTime,
    this.pausedAt,
    this.totalPausedMinutes = 0,
    this.shiftId,
    this.shiftCode,
    this.shiftName,
    this.remarks,
  });

  factory DplProductionPlanItem.fromJson(Map<String, dynamic> json) {
    // Backend may inline the part as a nested object:
    //   { ..., "part": {id, customer_part_no, part_name, description} }
    // or as flat fields (older endpoints).
    Map<String, dynamic> part = const {};
    final rawPart = json['part'];
    if (rawPart is Map) {
      part = Map<String, dynamic>.from(rawPart);
    }
    Map<String, dynamic> shift = const {};
    final rawShift = json['shift'];
    if (rawShift is Map) {
      shift = Map<String, dynamic>.from(rawShift);
    }

    String pickStr(List<dynamic> candidates) {
      for (final c in candidates) {
        if (c == null) continue;
        final s = c.toString();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    return DplProductionPlanItem(
      id: parseIntOr(json['id']),
      planNo: parseIntOr(json['plan_no'] ?? json['planNo']),
      partId: parseIntOr(
        json['part_id'] ?? json['partId'] ?? part['id'],
      ),
      partNumber: pickStr([
        json['part_number'],
        json['partNumber'],
        part['customer_part_no'],
        part['customerPartNo'],
        part['part_number'],
        part['partNumber'],
      ]),
      partDescription: pickStr([
        json['part_description'],
        json['partDescription'],
        part['description'],
      ]),
      partName: pickStr([
        json['part_name'],
        json['partName'],
        part['part_name'],
        part['partName'],
        part['name'],
      ]),
      planQty: parseIntOr(json['plan_qty'] ?? json['planQty']),
      sequence: parseIntOr(json['sequence']),
      status: parseStringOr(json['status'], 'pending'),
      actualQty: parseIntOr(json['actual_qty'] ?? json['actualQty']),
      startTime: parseDateTimeOrNull(json['start_time'] ?? json['startTime']),
      endTime: parseDateTimeOrNull(json['end_time'] ?? json['endTime']),
      pausedAt: parseDateTimeOrNull(json['paused_at'] ?? json['pausedAt']),
      totalPausedMinutes: parseIntOr(
        json['total_paused_minutes'] ?? json['totalPausedMinutes'],
      ),
      shiftId: parseIntOrNull(
        json['shift_id'] ?? json['shiftId'] ?? shift['id'],
      ),
      shiftCode: pickStr([
        json['shift_code'],
        json['shiftCode'],
        shift['code'],
      ]).isEmpty
          ? null
          : pickStr([json['shift_code'], json['shiftCode'], shift['code']]),
      shiftName: pickStr([
        json['shift_name'],
        json['shiftName'],
        shift['name'],
      ]).isEmpty
          ? null
          : pickStr([json['shift_name'], json['shiftName'], shift['name']]),
      remarks: json['remarks']?.toString(),
    );
  }

  /// Payload for `POST /plans/:id/items` or used as a row in `createPlans`.
  Map<String, dynamic> toCreateJson() => {
        'plan_no': planNo,
        'part_id': partId,
        'plan_qty': planQty,
        'sequence': sequence,
        if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
      };

  /// Payload for `PUT /plans/:planId/items/:itemId`.
  Map<String, dynamic> toUpdateJson() => {
        'plan_no': planNo,
        'part_id': partId,
        'plan_qty': planQty,
        'sequence': sequence,
        if (remarks != null) 'remarks': remarks,
      };

  double get completionPct =>
      planQty <= 0 ? 0 : (actualQty / planQty).clamp(0.0, 1.0);

  DplProductionPlanItem copyWith({
    int? id,
    int? planNo,
    int? partId,
    String? partNumber,
    String? partDescription,
    String? partName,
    int? planQty,
    int? sequence,
    String? status,
    int? actualQty,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? pausedAt,
    int? totalPausedMinutes,
    int? shiftId,
    String? shiftCode,
    String? shiftName,
    String? remarks,
  }) {
    return DplProductionPlanItem(
      id: id ?? this.id,
      planNo: planNo ?? this.planNo,
      partId: partId ?? this.partId,
      partNumber: partNumber ?? this.partNumber,
      partDescription: partDescription ?? this.partDescription,
      partName: partName ?? this.partName,
      planQty: planQty ?? this.planQty,
      sequence: sequence ?? this.sequence,
      status: status ?? this.status,
      actualQty: actualQty ?? this.actualQty,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pausedAt: pausedAt ?? this.pausedAt,
      totalPausedMinutes: totalPausedMinutes ?? this.totalPausedMinutes,
      shiftId: shiftId ?? this.shiftId,
      shiftCode: shiftCode ?? this.shiftCode,
      shiftName: shiftName ?? this.shiftName,
      remarks: remarks ?? this.remarks,
    );
  }
}
