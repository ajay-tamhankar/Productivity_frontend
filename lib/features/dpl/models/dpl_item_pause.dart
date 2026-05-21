import '_json_helpers.dart';

/// Returns the first non-null candidate parsed as int, or `null`.
/// Handles backend payloads where a foreign key may arrive as either a
/// scalar (`paused_by: 2`) or a nested map (`pausedBy: {id: 2, ...}`).
int? _pickInt(Object? a, Object? b, Object? c) {
  for (final v in [a, b, c]) {
    if (v == null) continue;
    final n = parseIntOrNull(v);
    if (n != null) return n;
  }
  return null;
}

/// One row from `dpl.dpl_item_pauses`.
///
/// Item pauses are PARALLEL to but SEPARATE from machine downtimes —
/// they live on the plan item itself and let a supervisor halt one
/// item with a captured reason while a different item on the same
/// plan keeps running.
class DplItemPause {
  final int id;
  final int planId;
  final int planItemId;

  /// Optional FK into `dpl.dpl_downtime_reasons`. Null when the
  /// supervisor used a free-text reason without picking a master.
  final int? reasonId;
  final String? reasonCode;
  final String? reasonName;

  /// Mandatory free-text reason captured on every pause.
  final String reasonText;

  final DateTime pausedAt;
  final DateTime? resumedAt;
  final DateTime? expectedResumeAt;

  /// Server-computed total minutes once the pause is resumed.
  final int? durationMinutes;

  final int? shiftId;

  /// `'active'` while still open, `'resumed'` once closed.
  final String status;

  final int? pausedByUserId;
  final String? pausedByName;
  final int? resumedByUserId;
  final String? resumedByName;

  /// Convenience snapshot included on the per-plan list endpoint so
  /// the UI can render which item each pause belongs to without an
  /// extra fetch. Null on the per-item list endpoint.
  final int? planItemNo;
  final int? planItemQty;

  const DplItemPause({
    required this.id,
    required this.planId,
    required this.planItemId,
    required this.reasonText,
    required this.pausedAt,
    required this.status,
    this.reasonId,
    this.reasonCode,
    this.reasonName,
    this.resumedAt,
    this.expectedResumeAt,
    this.durationMinutes,
    this.shiftId,
    this.pausedByUserId,
    this.pausedByName,
    this.resumedByUserId,
    this.resumedByName,
    this.planItemNo,
    this.planItemQty,
  });

  factory DplItemPause.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> mapOf(String key) {
      final v = json[key];
      return v is Map ? Map<String, dynamic>.from(v) : const {};
    }

    final pausedBy = mapOf('pausedBy');
    final resumedBy = mapOf('resumedBy');
    final reason = mapOf('reason');
    final planItem = mapOf('planItem');

    return DplItemPause(
      id: parseIntOr(json['id']),
      planId: parseIntOr(json['plan_id'] ?? json['planId']),
      planItemId:
          parseIntOr(json['plan_item_id'] ?? json['planItemId']),
      reasonId: parseIntOrNull(
        json['reason_id'] ?? json['reasonId'] ?? reason['id'],
      ),
      reasonCode: (json['reason_code'] ?? reason['reason_code'])
          ?.toString(),
      reasonName: (json['reason_name'] ?? reason['reason_name'])
          ?.toString(),
      reasonText:
          parseStringOr(json['reason_text'] ?? json['reasonText']),
      pausedAt: parseDateTimeOrNull(
            json['paused_at'] ?? json['pausedAt'],
          ) ??
          DateTime.now().toUtc(),
      resumedAt:
          parseDateTimeOrNull(json['resumed_at'] ?? json['resumedAt']),
      expectedResumeAt: parseDateTimeOrNull(
        json['expected_resume_at'] ?? json['expectedResumeAt'],
      ),
      durationMinutes: parseIntOrNull(
        json['duration_minutes'] ?? json['durationMinutes'],
      ),
      shiftId: parseIntOrNull(json['shift_id'] ?? json['shiftId']),
      status: parseStringOr(json['status'], 'active'),
      pausedByUserId: _pickInt(
        json['paused_by'],
        json['pausedBy'],
        pausedBy['id'],
      ),
      pausedByName: (pausedBy['name'] ??
              json['paused_by_name'] ??
              json['pausedByName'])
          ?.toString(),
      resumedByUserId: _pickInt(
        json['resumed_by'],
        json['resumedBy'],
        resumedBy['id'],
      ),
      resumedByName: (resumedBy['name'] ??
              json['resumed_by_name'] ??
              json['resumedByName'])
          ?.toString(),
      planItemNo: parseIntOrNull(planItem['plan_no']),
      planItemQty: parseIntOrNull(planItem['plan_qty']),
    );
  }

  bool get isActive => resumedAt == null;
}

/// Wrapped response of `POST /supervisor/.../resume`.
class DplItemResumeResult {
  final int pauseId;
  final int planItemId;
  final DateTime? resumedAt;
  final int durationMinutes;
  final int totalPausedMinutes;

  const DplItemResumeResult({
    required this.pauseId,
    required this.planItemId,
    required this.durationMinutes,
    required this.totalPausedMinutes,
    this.resumedAt,
  });

  factory DplItemResumeResult.fromJson(Map<String, dynamic> json) {
    return DplItemResumeResult(
      pauseId: parseIntOr(json['pause_id'] ?? json['pauseId']),
      planItemId:
          parseIntOr(json['plan_item_id'] ?? json['planItemId']),
      resumedAt:
          parseDateTimeOrNull(json['resumed_at'] ?? json['resumedAt']),
      durationMinutes:
          parseIntOr(json['duration_minutes'] ?? json['durationMinutes']),
      totalPausedMinutes: parseIntOr(
        json['total_paused_minutes'] ?? json['totalPausedMinutes'],
      ),
    );
  }
}
