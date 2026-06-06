import '_json_helpers.dart';

/// One row from `GET /manager/reports/downtime/events`.
///
/// Mirrors the per-event "Details" sheet in the Excel export — each
/// entry is a single closed downtime occurrence enriched with machine,
/// shift, supervisor, reason + category, and the supervisor's
/// free-text remarks. Distinct from [DplDowntimeEvent] (which is the
/// supervisor-side lifecycle object that can also be active).
class DplDowntimeEventDetail {
  final int id;
  final int planId;
  final int? planItemId;
  final int machineId;
  final String machineName;
  final int? shiftId;
  final String shiftCode;
  final int reasonId;
  final String reasonName;
  final String category;
  final int? supervisorUserId;
  final String supervisorName;
  final DateTime startTime;
  final DateTime? endTime;

  /// Plant-local date (YYYY-MM-DD) the event belongs to. Parsed as a
  /// naive midnight so downstream formatting treats it literally and
  /// doesn't shift it back into UTC.
  final DateTime? localDate;

  final int durationMinutes;
  final String remarks;
  final String status;

  const DplDowntimeEventDetail({
    required this.id,
    required this.planId,
    required this.machineId,
    required this.machineName,
    required this.shiftCode,
    required this.reasonId,
    required this.reasonName,
    required this.category,
    required this.supervisorName,
    required this.startTime,
    required this.durationMinutes,
    required this.remarks,
    required this.status,
    this.planItemId,
    this.shiftId,
    this.supervisorUserId,
    this.endTime,
    this.localDate,
  });

  factory DplDowntimeEventDetail.fromJson(Map<String, dynamic> json) {
    DateTime? localDate;
    final rawLocal = json['local_date'] ?? json['localDate'];
    if (rawLocal != null) {
      final str = rawLocal.toString().trim();
      if (str.isNotEmpty) {
        // Backend ships YYYY-MM-DD already in plant-local time. Parse as
        // a naive date so we never accidentally apply a timezone shift.
        final parsed = DateTime.tryParse(str.length == 10 ? '${str}T00:00:00' : str);
        if (parsed != null) {
          localDate = DateTime(parsed.year, parsed.month, parsed.day);
        }
      }
    }

    return DplDowntimeEventDetail(
      id: parseIntOr(json['id']),
      planId: parseIntOr(json['plan_id'] ?? json['planId']),
      planItemId:
          parseIntOrNull(json['plan_item_id'] ?? json['planItemId']),
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      machineName:
          parseStringOr(json['machine_name'] ?? json['machineName']),
      shiftId: parseIntOrNull(json['shift_id'] ?? json['shiftId']),
      shiftCode: parseStringOr(json['shift_code'] ?? json['shiftCode']),
      reasonId: parseIntOr(json['reason_id'] ?? json['reasonId']),
      reasonName:
          parseStringOr(json['reason_name'] ?? json['reasonName']),
      category: parseStringOr(json['category'], 'unplanned').toLowerCase(),
      supervisorUserId: parseIntOrNull(
        json['supervisor_user_id'] ?? json['supervisorUserId'],
      ),
      supervisorName: parseStringOr(
        json['supervisor_name'] ?? json['supervisorName'],
      ),
      startTime:
          parseDateTimeOrNull(json['start_time'] ?? json['startTime']) ??
              DateTime.now().toUtc(),
      endTime: parseDateTimeOrNull(json['end_time'] ?? json['endTime']),
      localDate: localDate,
      durationMinutes:
          parseIntOr(json['duration_minutes'] ?? json['durationMinutes']),
      remarks: parseStringOr(json['remarks']),
      status: parseStringOr(json['status'], 'resolved').toLowerCase(),
    );
  }

  bool get hasRemarks => remarks.trim().isNotEmpty;
  bool get isPlanned => category == 'planned';
}
