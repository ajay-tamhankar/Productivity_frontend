import '_json_helpers.dart';
import 'dpl_production_plan_item.dart';

class DplProductionPlan {
  final int id;
  final DateTime planDate;
  final int machineId;
  final String machineName;
  final int supervisorUserId;
  final String supervisorName;
  final int managerUserId;
  final String managerName;
  final int totalPlanQty;
  final int totalActualQty;
  final String planReleasedBy;
  final String planApprovedBy;
  /// draft / published / in_progress / completed / locked
  final String status;
  final String? remarks;
  final List<DplProductionPlanItem> items;

  const DplProductionPlan({
    required this.id,
    required this.planDate,
    required this.machineId,
    required this.machineName,
    required this.supervisorUserId,
    required this.supervisorName,
    required this.managerUserId,
    required this.totalPlanQty,
    this.managerName = '',
    this.totalActualQty = 0,
    this.planReleasedBy = '',
    this.planApprovedBy = '',
    this.status = 'draft',
    this.remarks,
    this.items = const [],
  });

  factory DplProductionPlan.fromJson(Map<String, dynamic> json) {
    // Backend nests machine / supervisor / manager:
    //   { ..., machine: {...}, supervisor: {...}, manager: {...}, items: [...] }
    Map<String, dynamic> mapOf(String key) {
      final v = json[key];
      return v is Map ? Map<String, dynamic>.from(v) : const {};
    }

    final machine = mapOf('machine');
    final supervisor = mapOf('supervisor');
    final manager = mapOf('manager');

    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => DplProductionPlanItem.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList()
        : <DplProductionPlanItem>[];

    String pickStr(List<dynamic> candidates) {
      for (final c in candidates) {
        if (c == null) continue;
        final s = c.toString();
        if (s.isNotEmpty) return s;
      }
      return '';
    }

    return DplProductionPlan(
      id: parseIntOr(json['id']),
      planDate: parseDateTimeOrNull(json['plan_date'] ?? json['planDate']) ??
          DateTime.now(),
      machineId: parseIntOr(
        json['machine_id'] ?? json['machineId'] ?? machine['id'],
      ),
      machineName: pickStr([
        json['machine_name'],
        json['machineName'],
        machine['machine_name'],
        machine['machineName'],
        machine['name'],
      ]),
      supervisorUserId: parseIntOr(
        json['supervisor_user_id'] ??
            json['supervisorUserId'] ??
            supervisor['id'],
      ),
      supervisorName: pickStr([
        json['supervisor_name'],
        json['supervisorName'],
        supervisor['name'],
        supervisor['full_name'],
      ]),
      managerUserId: parseIntOr(
        json['manager_user_id'] ??
            json['managerUserId'] ??
            manager['id'],
      ),
      managerName: pickStr([
        json['manager_name'],
        json['managerName'],
        manager['name'],
      ]),
      totalPlanQty:
          parseIntOr(json['total_plan_qty'] ?? json['totalPlanQty']),
      totalActualQty:
          parseIntOr(json['total_actual_qty'] ?? json['totalActualQty']),
      planReleasedBy:
          parseStringOr(json['plan_released_by'] ?? json['planReleasedBy']),
      planApprovedBy:
          parseStringOr(json['plan_approved_by'] ?? json['planApprovedBy']),
      status: parseStringOr(json['status'], 'draft'),
      remarks: json['remarks']?.toString(),
      items: items,
    );
  }

  /// Sum of every item's plan_qty. Falls back to the API's stored
  /// header value when [items] hasn't been loaded yet (e.g. list
  /// endpoints that don't include items).
  int get effectiveTotalPlanQty {
    if (items.isEmpty) return totalPlanQty;
    final sum = items.fold<int>(0, (a, i) => a + i.planQty);
    // Prefer the items sum whenever it gives a positive number — the
    // backend's stored header column is known to drift to 0 because
    // there's no write-side hook on start/stop/updateActual yet.
    return sum > 0 ? sum : totalPlanQty;
  }

  /// Sum of every item's actual_qty. Same fallback as
  /// [effectiveTotalPlanQty].
  int get effectiveTotalActualQty {
    if (items.isEmpty) return totalActualQty;
    final sum = items.fold<int>(0, (a, i) => a + i.actualQty);
    // Stored value can be 0 even when items have actuals (no
    // write-side hook on the header column). Trust the items sum
    // whenever items are present; only fall back to the stored value
    // for endpoints that don't return items.
    return items.any((i) => i.actualQty > 0) ? sum : totalActualQty;
  }

  double get completionPct {
    final plan = effectiveTotalPlanQty;
    final actual = effectiveTotalActualQty;
    if (plan <= 0) return 0;
    return (actual / plan).clamp(0.0, 1.0);
  }

  /// Distinct shift tokens (code if available, else `#<id>`) derived
  /// from this plan's items, sorted for stable display. Empty when no
  /// item has been started yet — shift is auto-tagged on first START.
  List<String> get shiftCodes {
    final seen = <String>{};
    for (final i in items) {
      final code = (i.shiftCode ?? '').trim();
      if (code.isNotEmpty) {
        seen.add(code);
      } else if (i.shiftId != null) {
        seen.add('#${i.shiftId}');
      }
    }
    final list = seen.toList()..sort();
    return list;
  }

  /// Human label for [shiftCodes]:
  ///   • single shift   → "Shift A"
  ///   • multiple       → "Shifts A, B"
  ///   • none assigned  → "" (caller should hide the chip)
  String get shiftLabel {
    final codes = shiftCodes;
    if (codes.isEmpty) return '';
    if (codes.length == 1) return 'Shift ${codes.first}';
    return 'Shifts ${codes.join(', ')}';
  }

  /// `true` when nothing on this plan has been touched yet — every
  /// item is still pending and no actual qty has been booked. Used
  /// to gate plan-level Delete: once any item is in progress or
  /// completed, the plan carries data we shouldn't drop silently.
  bool get isAllItemsPending {
    if (items.isEmpty) return true;
    for (final i in items) {
      if (i.status != 'pending') return false;
      if (i.actualQty > 0) return false;
      if (i.startTime != null) return false;
    }
    return true;
  }

  /// Plan-level Delete is allowed when the plan isn't locked AND no
  /// supervisor activity exists on it yet. Wider than the old
  /// "draft-only" rule so a Published plan that's never been started
  /// can still be removed.
  bool get isDeletable => status != 'locked' && isAllItemsPending;

  DplProductionPlan copyWith({
    int? id,
    DateTime? planDate,
    int? machineId,
    String? machineName,
    int? supervisorUserId,
    String? supervisorName,
    int? managerUserId,
    String? managerName,
    int? totalPlanQty,
    int? totalActualQty,
    String? planReleasedBy,
    String? planApprovedBy,
    String? status,
    String? remarks,
    List<DplProductionPlanItem>? items,
  }) {
    return DplProductionPlan(
      id: id ?? this.id,
      planDate: planDate ?? this.planDate,
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      supervisorUserId: supervisorUserId ?? this.supervisorUserId,
      supervisorName: supervisorName ?? this.supervisorName,
      managerUserId: managerUserId ?? this.managerUserId,
      managerName: managerName ?? this.managerName,
      totalPlanQty: totalPlanQty ?? this.totalPlanQty,
      totalActualQty: totalActualQty ?? this.totalActualQty,
      planReleasedBy: planReleasedBy ?? this.planReleasedBy,
      planApprovedBy: planApprovedBy ?? this.planApprovedBy,
      status: status ?? this.status,
      remarks: remarks ?? this.remarks,
      items: items ?? this.items,
    );
  }
}

/// Wrapper for a `POST /plans` payload covering 1..N machines for a single
/// date. The Upload Plan screen builds this from either the Excel preview
/// or the manual-entry form.
class DplCreatePlansRequest {
  final DateTime planDate;
  final int supervisorUserId;
  final String planReleasedBy;
  final String planApprovedBy;
  final String? remarks;
  /// Optional — when set, every item in the submission is pre-tagged
  /// with this shift. When null, the backend auto-derives `shift_id`
  /// from each item's first START click.
  final int? shiftId;
  final List<DplCreatePlanForMachine> machines;

  const DplCreatePlansRequest({
    required this.planDate,
    required this.supervisorUserId,
    required this.planReleasedBy,
    required this.planApprovedBy,
    required this.machines,
    this.shiftId,
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'plan_date': _ymd(planDate),
        'supervisor_user_id': supervisorUserId,
        'plan_released_by': planReleasedBy,
        'plan_approved_by': planApprovedBy,
        if (remarks != null && remarks!.isNotEmpty) 'remarks': remarks,
        if (shiftId != null) 'shift_id': shiftId,
        // Backend expects this array under the key `plans` (one entry
        // per machine), NOT `machines`.
        'plans': machines
            .map((m) => m.toJson(defaultShiftId: shiftId))
            .toList(),
      };

  static String _ymd(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class DplCreatePlanForMachine {
  final int machineId;
  final List<DplProductionPlanItem> items;

  const DplCreatePlanForMachine({
    required this.machineId,
    required this.items,
  });

  Map<String, dynamic> toJson({int? defaultShiftId}) => {
        'machine_id': machineId,
        'shift_id': ?defaultShiftId,
        'items': items
            .map((i) {
              final body = i.toCreateJson();
              // Per-item shift takes precedence over the request-wide
              // default, so manual overrides still work later.
              if (defaultShiftId != null && body['shift_id'] == null) {
                body['shift_id'] = defaultShiftId;
              }
              return body;
            })
            .toList(),
      };
}

/// Wrapper for a `PUT /plans/:id` payload (header fields only — items
/// have their own endpoints).
class DplUpdatePlanRequest {
  final int? supervisorUserId;
  final String? planReleasedBy;
  final String? planApprovedBy;
  final String? remarks;
  final String? status;

  const DplUpdatePlanRequest({
    this.supervisorUserId,
    this.planReleasedBy,
    this.planApprovedBy,
    this.remarks,
    this.status,
  });

  Map<String, dynamic> toJson() => {
        if (supervisorUserId != null) 'supervisor_user_id': supervisorUserId,
        if (planReleasedBy != null) 'plan_released_by': planReleasedBy,
        if (planApprovedBy != null) 'plan_approved_by': planApprovedBy,
        if (remarks != null) 'remarks': remarks,
        if (status != null) 'status': status,
      };

  bool get isEmpty => toJson().isEmpty;
}
