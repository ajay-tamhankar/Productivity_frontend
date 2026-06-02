import '_json_helpers.dart';

/// One row from `dpl_trolley_photos` — the photo a supervisor must
/// capture before stopping a running plan item.
class DplTrolleyPhoto {
  final int id;
  final int planId;
  final int planItemId;
  final int? supervisorUserId;
  final String? supervisorName;
  final int? machineId;
  final String? machineName;
  final DateTime capturedAt;
  /// Server-relative URL to the raw image bytes. Use the API client to
  /// fetch via Bearer auth — never embed directly in an `<img>` tag.
  final String photoUrl;
  final String? remarks;
  final String? mimeType;
  final int? sizeBytes;

  const DplTrolleyPhoto({
    required this.id,
    required this.planId,
    required this.planItemId,
    required this.capturedAt,
    required this.photoUrl,
    this.supervisorUserId,
    this.supervisorName,
    this.machineId,
    this.machineName,
    this.remarks,
    this.mimeType,
    this.sizeBytes,
  });

  factory DplTrolleyPhoto.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> mapOf(String key) {
      final v = json[key];
      return v is Map ? Map<String, dynamic>.from(v) : const {};
    }

    final supervisor = mapOf('supervisor');
    final machine = mapOf('machine');

    return DplTrolleyPhoto(
      id: parseIntOr(json['id']),
      planId: parseIntOr(json['plan_id'] ?? json['planId']),
      planItemId:
          parseIntOr(json['plan_item_id'] ?? json['planItemId']),
      supervisorUserId: parseIntOrNull(
        json['supervisor_user_id'] ??
            json['supervisorUserId'] ??
            supervisor['id'],
      ),
      supervisorName: parseStringOr(
        json['supervisor_name'] ??
            json['supervisorName'] ??
            supervisor['name'],
      ).isEmpty
          ? null
          : parseStringOr(
              json['supervisor_name'] ??
                  json['supervisorName'] ??
                  supervisor['name'],
            ),
      machineId: parseIntOrNull(
        json['machine_id'] ?? json['machineId'] ?? machine['id'],
      ),
      machineName: parseStringOr(
        json['machine_name'] ?? json['machineName'] ?? machine['name'],
      ).isEmpty
          ? null
          : parseStringOr(
              json['machine_name'] ?? json['machineName'] ?? machine['name'],
            ),
      capturedAt: parseDateTimeOrNull(
            json['captured_at'] ?? json['capturedAt'],
          ) ??
          DateTime.now().toUtc(),
      photoUrl:
          parseStringOr(json['photo_url'] ?? json['photoUrl']),
      remarks: json['remarks']?.toString(),
      mimeType: (json['mime_type'] ?? json['mimeType'])?.toString(),
      sizeBytes: parseIntOrNull(json['size_bytes'] ?? json['sizeBytes']),
    );
  }
}
