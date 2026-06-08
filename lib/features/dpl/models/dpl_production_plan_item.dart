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
  /// Total minutes the item has spent paused — sum of [downtimeMinutes]
  /// and [manualPauseMinutes]. Kept for backwards-compat with code that
  /// was reading this single accumulator before the backend split it.
  final int totalPausedMinutes;

  /// Minutes lost to machine downtime on this item — sourced from
  /// `dpl_downtime_events` (status = `resolved`).
  final int downtimeMinutes;

  /// Minutes the supervisor manually paused this item — sourced from
  /// `dpl_plan_item_pauses` (status = `resumed`). These are pauses
  /// with a free-text reason, distinct from machine downtime.
  final int manualPauseMinutes;
  /// Shift the item ran in — server-derived from `start_time`. Null for
  /// items started before the column was added or never started.
  final int? shiftId;
  final String? shiftCode;
  final String? shiftName;
  final String? remarks;

  /// Server-relative URL of the trolley photo captured at STOP time.
  /// `null` until the item is stopped; only present on stopped items.
  final String? stopTrolleyPhotoUrl;

  /// When set on a CREATE payload, links the new item to a leftover
  /// item from a previous plan (see
  /// `GET /manager/plans/carry-forward-candidates`). The backend uses
  /// this to remove the source from future candidate listings and
  /// stamps the new row's `carried_from_item_id` column.
  final int? carriedFromItemId;

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
    this.downtimeMinutes = 0,
    this.manualPauseMinutes = 0,
    this.shiftId,
    this.shiftCode,
    this.shiftName,
    this.remarks,
    this.stopTrolleyPhotoUrl,
    this.carriedFromItemId,
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
      downtimeMinutes: parseIntOr(
        json['downtime_minutes'] ?? json['downtimeMinutes'],
      ),
      manualPauseMinutes: parseIntOr(
        json['manual_pause_minutes'] ?? json['manualPauseMinutes'],
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
      stopTrolleyPhotoUrl: () {
        final raw = json['stop_trolley_photo_url'] ??
            json['stopTrolleyPhotoUrl'];
        if (raw == null) return null;
        final text = raw.toString().trim();
        return text.isEmpty ? null : text;
      }(),
      carriedFromItemId: parseIntOrNull(
        json['carried_from_item_id'] ?? json['carriedFromItemId'],
      ),
    );
  }

  /// Payload for `POST /plans/:id/items` or used as a row in `createPlans`.
  /// `shift_id` is sent only when set; null is intentionally omitted so
  /// the backend keeps its auto-derive-on-first-start behaviour.
  Map<String, dynamic> toCreateJson() => {
        'plan_no': planNo,
        'part_id': partId,
        'plan_qty': planQty,
        'sequence': sequence,
        if (shiftId != null) 'shift_id': shiftId,
        if (carriedFromItemId != null)
          'carried_from_item_id': carriedFromItemId,
        if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
      };

  /// Payload for `PUT /plans/:planId/items/:itemId`.
  Map<String, dynamic> toUpdateJson() => {
        'plan_no': planNo,
        'part_id': partId,
        'plan_qty': planQty,
        'sequence': sequence,
        if (shiftId != null) 'shift_id': shiftId,
        if (remarks != null) 'remarks': remarks,
      };

  double get completionPct => planQty <= 0 ? 0 : actualQty / planQty;

  /// Display label for the shift, e.g. "Shift A".
  ///
  /// Backend returns `shift_id` as soon as the supervisor starts an
  /// item but doesn't always join `shift_code`/`shift_name` text. Fall
  /// back to "Shift #N" so the supervisor still sees something.
  /// Returns `null` when neither id nor code is known.
  String? get shiftDisplayLabel {
    final code = (shiftCode ?? '').trim();
    if (code.isNotEmpty) return 'Shift $code';
    if (shiftId != null) return 'Shift #$shiftId';
    return null;
  }

  /// Display-order rank.
  ///
  ///   0 → in_progress  (work the supervisor needs to touch first)
  ///   1 → pending      (queued items, ordered by plan_no underneath)
  ///   2 → completed    (done items pinned to the bottom)
  ///   3 → anything else
  int get _statusRank {
    switch (status) {
      case 'in_progress':
        return 0;
      case 'pending':
        return 1;
      case 'completed':
        return 2;
      default:
        return 3;
    }
  }

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
    int? downtimeMinutes,
    int? manualPauseMinutes,
    int? shiftId,
    String? shiftCode,
    String? shiftName,
    String? remarks,
    String? stopTrolleyPhotoUrl,
    int? carriedFromItemId,
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
      downtimeMinutes: downtimeMinutes ?? this.downtimeMinutes,
      manualPauseMinutes: manualPauseMinutes ?? this.manualPauseMinutes,
      shiftId: shiftId ?? this.shiftId,
      shiftCode: shiftCode ?? this.shiftCode,
      shiftName: shiftName ?? this.shiftName,
      remarks: remarks ?? this.remarks,
      stopTrolleyPhotoUrl: stopTrolleyPhotoUrl ?? this.stopTrolleyPhotoUrl,
      carriedFromItemId: carriedFromItemId ?? this.carriedFromItemId,
    );
  }
}

/// Helpers for rendering plan-item lists.
extension DplProductionPlanItemListSorting on List<DplProductionPlanItem> {
  /// Returns a new list ordered for the operator's plan view:
  ///   1. In-progress items first
  ///   2. Pending items next, sorted by plan_no ascending
  ///   3. Completed items pinned to the bottom (also by plan_no)
  /// Ties are broken by `sequence` then `id` so the order is stable.
  List<DplProductionPlanItem> sortedForExecution() {
    final copy = List<DplProductionPlanItem>.from(this);
    copy.sort((a, b) {
      final byStatus = a._statusRank.compareTo(b._statusRank);
      if (byStatus != 0) return byStatus;
      final byPlanNo = a.planNo.compareTo(b.planNo);
      if (byPlanNo != 0) return byPlanNo;
      final bySequence = a.sequence.compareTo(b.sequence);
      if (bySequence != 0) return bySequence;
      return a.id.compareTo(b.id);
    });
    return copy;
  }
}
