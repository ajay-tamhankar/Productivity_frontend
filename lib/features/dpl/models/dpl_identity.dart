import '_json_helpers.dart';

/// Per-shift snippet returned inside [DplIdentityStatus] so the client
/// can show the shift name on the lock screen without a separate fetch
/// to the shifts master (which is manager-only).
class DplIdentityCurrentShift {
  final int id;
  final String code;
  final String name;
  final String startTime;
  final String endTime;
  final DateTime? startsAt;
  final DateTime? endsAt;

  const DplIdentityCurrentShift({
    required this.id,
    required this.code,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.startsAt,
    this.endsAt,
  });

  factory DplIdentityCurrentShift.fromJson(Map<String, dynamic> json) {
    return DplIdentityCurrentShift(
      id: parseIntOr(json['id']),
      code: parseStringOr(json['code']),
      name: parseStringOr(json['name']),
      startTime: parseStringOr(json['start_time'] ?? json['startTime']),
      endTime: parseStringOr(json['end_time'] ?? json['endTime']),
      startsAt: parseDateTimeOrNull(json['starts_at'] ?? json['startsAt']),
      endsAt: parseDateTimeOrNull(json['ends_at'] ?? json['endsAt']),
    );
  }

  /// "07:30 → 15:00"
  String get windowLabel {
    String short(String hms) {
      final t = hms.trim();
      return t.length >= 5 ? t.substring(0, 5) : t;
    }

    final s = short(startTime);
    final e = short(endTime);
    if (s.isEmpty || e.isEmpty) return '';
    return '$s → $e';
  }
}

/// Response of `GET /supervisor/identity/status`.
///
/// As of 2026-05-19 the server owns the shift-based rule and exposes
/// [verifiedForCurrentShift] / [currentShift]; the legacy [verified] +
/// [validUntil] fields are kept for fallback when no shift covers
/// `now()`.
class DplIdentityStatus {
  /// Whether the backend currently requires identity verification at
  /// all (admin can globally turn this off via `DPL_IDENTITY_REQUIRED`).
  final bool required;

  /// Legacy 30-minute window flag. Only consulted when [currentShift]
  /// is null (gap between scheduled shifts).
  final bool verified;

  /// When the legacy verification expires. `null` when not verified.
  final DateTime? validUntil;

  /// Timestamp of the latest verification, if any.
  final DateTime? lastVerifiedAt;

  /// The shift covering `now()` per the server's plant TZ. `null` when
  /// no shift schedule covers this moment.
  final DplIdentityCurrentShift? currentShift;

  /// Server-computed: `true` iff the supervisor has an un-flagged
  /// verification on file for [currentShift]. When [currentShift] is
  /// null this falls back to [verified].
  final bool verifiedForCurrentShift;

  const DplIdentityStatus({
    required this.required,
    required this.verified,
    required this.verifiedForCurrentShift,
    this.validUntil,
    this.lastVerifiedAt,
    this.currentShift,
  });

  factory DplIdentityStatus.fromJson(Map<String, dynamic> json) {
    bool readBool(dynamic v) {
      if (v is bool) return v;
      return v?.toString().toLowerCase() == 'true';
    }

    final shiftRaw = json['current_shift'] ?? json['currentShift'];
    DplIdentityCurrentShift? shift;
    if (shiftRaw is Map) {
      shift = DplIdentityCurrentShift.fromJson(
        Map<String, dynamic>.from(shiftRaw),
      );
    }

    final verified = readBool(json['verified']);
    final hasShiftFlag = json.containsKey('verified_for_current_shift') ||
        json.containsKey('verifiedForCurrentShift');
    final verifiedForShift = hasShiftFlag
        ? readBool(json['verified_for_current_shift'] ??
            json['verifiedForCurrentShift'])
        : verified; // Legacy server fallback.

    return DplIdentityStatus(
      required: readBool(json['required']),
      verified: verified,
      validUntil: parseDateTimeOrNull(
        json['valid_until'] ?? json['validUntil'],
      ),
      lastVerifiedAt: parseDateTimeOrNull(
        json['last_verified_at'] ?? json['lastVerifiedAt'],
      ),
      currentShift: shift,
      verifiedForCurrentShift: verifiedForShift,
    );
  }

  /// Legacy 30-minute window check, kept only as a safety net for the
  /// per-tap [IdentityGate] when status hasn't refreshed yet.
  bool get isCurrentlyValid {
    if (!verified) return false;
    if (validUntil == null) return false;
    return validUntil!.isAfter(DateTime.now().toUtc());
  }
}

/// A single row from `dpl.dpl_identity_verifications` — used by both
/// the supervisor's verify-response and the manager's audit list.
class DplIdentityVerification {
  final int id;
  final int? supervisorId;
  final String? supervisorName;
  /// 'login' | 'plan_access' | 'item_start' | 'downtime_start'
  final String context;
  final int? planId;
  final int? planItemId;
  final int? shiftId;
  final String? shiftCode;
  final String? shiftName;
  final String photoMime;
  final int photoSize;
  final String deviceIp;
  final String userAgent;
  final DateTime createdAt;
  final DateTime? validUntil;
  final bool flagged;
  final String? flagReason;
  final DateTime? flaggedAt;
  final int? flaggedBy;

  const DplIdentityVerification({
    required this.id,
    required this.context,
    required this.createdAt,
    this.supervisorId,
    this.supervisorName,
    this.planId,
    this.planItemId,
    this.shiftId,
    this.shiftCode,
    this.shiftName,
    this.photoMime = '',
    this.photoSize = 0,
    this.deviceIp = '',
    this.userAgent = '',
    this.validUntil,
    this.flagged = false,
    this.flagReason,
    this.flaggedAt,
    this.flaggedBy,
  });

  factory DplIdentityVerification.fromJson(Map<String, dynamic> json) {
    return DplIdentityVerification(
      id: parseIntOr(json['id']),
      supervisorId: parseIntOrNull(
        json['supervisor_id'] ?? json['supervisorId'],
      ),
      supervisorName: json['supervisor_name']?.toString() ??
          json['supervisorName']?.toString(),
      context: parseStringOr(json['context'], 'plan_access'),
      planId: parseIntOrNull(json['plan_id'] ?? json['planId']),
      planItemId:
          parseIntOrNull(json['plan_item_id'] ?? json['planItemId']),
      shiftId: parseIntOrNull(json['shift_id'] ?? json['shiftId']),
      shiftCode: json['shift_code']?.toString() ??
          json['shiftCode']?.toString(),
      shiftName: json['shift_name']?.toString() ??
          json['shiftName']?.toString(),
      photoMime:
          parseStringOr(json['photo_mime'] ?? json['photoMime']),
      photoSize: parseIntOr(json['photo_size'] ?? json['photoSize']),
      deviceIp: parseStringOr(json['device_ip'] ?? json['deviceIp']),
      userAgent: parseStringOr(json['user_agent'] ?? json['userAgent']),
      createdAt:
          parseDateTimeOrNull(json['created_at'] ?? json['createdAt']) ??
              DateTime.now().toUtc(),
      validUntil:
          parseDateTimeOrNull(json['valid_until'] ?? json['validUntil']),
      flagged: json['flagged'] is bool
          ? json['flagged'] as bool
          : json['flagged']?.toString().toLowerCase() == 'true',
      flagReason: json['flag_reason']?.toString() ??
          json['flagReason']?.toString(),
      flaggedAt:
          parseDateTimeOrNull(json['flagged_at'] ?? json['flaggedAt']),
      flaggedBy: parseIntOrNull(json['flagged_by'] ?? json['flaggedBy']),
    );
  }

  /// Convenience for the manager audit screen.
  bool get isExpired =>
      validUntil != null && validUntil!.isBefore(DateTime.now().toUtc());
}
