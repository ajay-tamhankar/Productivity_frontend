import '_json_helpers.dart';

/// One row in `dpl.dpl_manpower_log` — headcount for a (date, shift,
/// optional machine) tuple.
///
/// `machineId == null` means "shift-wide headcount" (the whole shift,
/// not pinned to a specific machine). The backend enforces a partial
/// unique index on both (date, shift, machine) and (date, shift, NULL).
class DplManpowerLog {
  final int id;
  final DateTime date;
  final int shiftId;
  final int? machineId;
  final int headcount;
  final int? createdBy;
  final DateTime? createdAt;
  // Optional joined fields the backend may include:
  final String shiftCode;
  final String shiftName;
  final String machineName;

  const DplManpowerLog({
    required this.id,
    required this.date,
    required this.shiftId,
    required this.headcount,
    this.machineId,
    this.createdBy,
    this.createdAt,
    this.shiftCode = '',
    this.shiftName = '',
    this.machineName = '',
  });

  factory DplManpowerLog.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> shiftMap = const {};
    final rawShift = json['shift'];
    if (rawShift is Map) shiftMap = Map<String, dynamic>.from(rawShift);
    Map<String, dynamic> machineMap = const {};
    final rawMachine = json['machine'];
    if (rawMachine is Map) machineMap = Map<String, dynamic>.from(rawMachine);

    return DplManpowerLog(
      id: parseIntOr(json['id']),
      date: parseDateTimeOrNull(json['date']) ?? DateTime.now(),
      shiftId: parseIntOr(
        json['shift_id'] ?? json['shiftId'] ?? shiftMap['id'],
      ),
      machineId: parseIntOrNull(
        json['machine_id'] ?? json['machineId'] ?? machineMap['id'],
      ),
      headcount: parseIntOr(json['headcount']),
      createdBy: parseIntOrNull(json['created_by'] ?? json['createdBy']),
      createdAt: parseDateTimeOrNull(json['created_at'] ?? json['createdAt']),
      shiftCode: parseStringOr(
        json['shift_code'] ?? json['shiftCode'] ?? shiftMap['code'],
      ),
      shiftName: parseStringOr(
        json['shift_name'] ?? json['shiftName'] ?? shiftMap['name'],
      ),
      machineName: parseStringOr(
        json['machine_name'] ??
            json['machineName'] ??
            machineMap['machine_name'] ??
            machineMap['name'],
      ),
    );
  }

  /// Payload for `POST /manager/manpower` and `POST /supervisor/manpower/today`
  /// (the supervisor endpoint takes an array of these).
  Map<String, dynamic> toCreateJson() {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return {
      'date': '$y-$m-$d',
      'shift_id': shiftId,
      if (machineId != null) 'machine_id': machineId,
      'headcount': headcount,
    };
  }

  Map<String, dynamic> toUpdateJson() => {'headcount': headcount};

  DplManpowerLog copyWith({
    int? id,
    DateTime? date,
    int? shiftId,
    int? machineId,
    int? headcount,
  }) {
    return DplManpowerLog(
      id: id ?? this.id,
      date: date ?? this.date,
      shiftId: shiftId ?? this.shiftId,
      machineId: machineId ?? this.machineId,
      headcount: headcount ?? this.headcount,
      createdBy: createdBy,
      createdAt: createdAt,
      shiftCode: shiftCode,
      shiftName: shiftName,
      machineName: machineName,
    );
  }
}
