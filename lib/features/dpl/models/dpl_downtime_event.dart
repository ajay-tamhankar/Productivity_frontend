import '_json_helpers.dart';

class DplDowntimeEvent {
  final int id;
  final int planId;
  final int? planItemId;
  final int machineId;
  final int reasonId;
  final String reasonName;
  final String? category;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationMinutes;
  final String? remarks;
  /// active | resolved
  final String status;
  /// Shift the downtime started in — auto-derived server-side.
  final int? shiftId;
  final String? shiftCode;

  const DplDowntimeEvent({
    required this.id,
    required this.planId,
    required this.machineId,
    required this.reasonId,
    required this.reasonName,
    required this.startTime,
    required this.status,
    this.planItemId,
    this.category,
    this.endTime,
    this.durationMinutes,
    this.remarks,
    this.shiftId,
    this.shiftCode,
  });

  factory DplDowntimeEvent.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> reasonMap = const {};
    final rawReason = json['reason'];
    if (rawReason is Map) reasonMap = Map<String, dynamic>.from(rawReason);
    Map<String, dynamic> shiftMap = const {};
    final rawShift = json['shift'];
    if (rawShift is Map) shiftMap = Map<String, dynamic>.from(rawShift);

    return DplDowntimeEvent(
      id: parseIntOr(json['id']),
      planId: parseIntOr(json['plan_id'] ?? json['planId']),
      planItemId:
          parseIntOrNull(json['plan_item_id'] ?? json['planItemId']),
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      reasonId: parseIntOr(
        json['reason_id'] ?? json['reasonId'] ?? reasonMap['id'],
      ),
      reasonName: parseStringOr(
        json['reason_name'] ??
            json['reasonName'] ??
            reasonMap['reason_name'] ??
            reasonMap['name'],
      ),
      category: (json['category'] ?? reasonMap['category'])?.toString(),
      startTime:
          parseDateTimeOrNull(json['start_time'] ?? json['startTime']) ??
              DateTime.now().toUtc(),
      endTime: parseDateTimeOrNull(json['end_time'] ?? json['endTime']),
      durationMinutes:
          parseIntOrNull(json['duration_minutes'] ?? json['durationMinutes']),
      remarks: json['remarks']?.toString(),
      status: parseStringOr(json['status'], 'active').toLowerCase(),
      shiftId: parseIntOrNull(
        json['shift_id'] ?? json['shiftId'] ?? shiftMap['id'],
      ),
      shiftCode: parseStringOr(
        json['shift_code'] ?? json['shiftCode'] ?? shiftMap['code'],
      ).isEmpty
          ? null
          : parseStringOr(
              json['shift_code'] ?? json['shiftCode'] ?? shiftMap['code'],
            ),
    );
  }

  bool get isActive => status == 'active';
}
