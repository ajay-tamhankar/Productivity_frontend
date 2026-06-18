import '../core/dpl_dispatch_calculator.dart';
import '_json_helpers.dart';

/// Server-side warning codes the backend may attach to a part row.
/// Strings only — the FE shows them as chips on the Today's Plan screen
/// and uses presence/absence to decide whether to include the part in
/// the calculator run.
class DplDispatchPlanWarning {
  /// No row in `dpl_buffer_norms` for (plant, part). Calculator can't
  /// run — the manager needs to seed the norm first.
  static const String missingBufferNorm = 'MISSING_BUFFER_NORM';

  /// No row in `dpl_daily_customer_snapshot` for (plant, part, date).
  /// Manager / Dispatch needs to enter this morning's data first.
  static const String missingCustomerSnapshot = 'MISSING_CUSTOMER_SNAPSHOT';

  /// Human-readable label for a warning code.
  static String labelFor(String code) {
    switch (code) {
      case missingBufferNorm:
        return 'Buffer norm not set';
      case missingCustomerSnapshot:
        return 'Today\'s stock not entered';
      default:
        return code;
    }
  }
}

/// One part row in the `dispatch-plan/inputs` response.
///
/// Field names match `DispatchCalcInput`'s named parameters 1:1, so
/// the FE constructs the calculator input via [toCalcInput].
class DplDispatchPlanInputRow {
  final int partId;
  final String customerPn;
  final String description;
  final String partName;
  final int machineId;
  final String machineName;

  /// Master-data inputs — null when `warnings` contains
  /// `MISSING_BUFFER_NORM`.
  final int? bufferTargetAtTml;
  final int? trolleyCapacity;
  final int? tripsPerDay;

  /// Daily snapshot inputs — null when `warnings` contains
  /// `MISSING_CUSTOMER_SNAPSHOT`.
  final int? tmlOpeningStock;
  final int? customerPlanToday;

  /// Always present — backend computes from production summary + plan.
  final int gaOpeningStock;
  final int gaProductionToday;

  /// Per-row warnings — see [DplDispatchPlanWarning] for known codes.
  /// Empty when the row is fully ready to feed the calculator.
  final List<String> warnings;

  const DplDispatchPlanInputRow({
    required this.partId,
    this.customerPn = '',
    this.description = '',
    this.partName = '',
    required this.machineId,
    this.machineName = '',
    this.bufferTargetAtTml,
    this.trolleyCapacity,
    this.tripsPerDay,
    this.tmlOpeningStock,
    this.customerPlanToday,
    this.gaOpeningStock = 0,
    this.gaProductionToday = 0,
    this.warnings = const [],
  });

  factory DplDispatchPlanInputRow.fromJson(Map<String, dynamic> json) {
    return DplDispatchPlanInputRow(
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      customerPn: parseStringOr(json['customer_pn'] ?? json['customerPn']),
      description: parseStringOr(json['description']),
      partName: parseStringOr(json['part_name'] ?? json['partName']),
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      machineName: parseStringOr(json['machine_name'] ?? json['machineName']),
      bufferTargetAtTml: parseIntOrNull(
        json['buffer_target_at_tml'] ?? json['bufferTargetAtTml'],
      ),
      trolleyCapacity: parseIntOrNull(
        json['trolley_capacity'] ?? json['trolleyCapacity'],
      ),
      tripsPerDay: parseIntOrNull(
        json['trips_per_day'] ?? json['tripsPerDay'],
      ),
      tmlOpeningStock: parseIntOrNull(
        json['tml_opening_stock'] ?? json['tmlOpeningStock'],
      ),
      customerPlanToday: parseIntOrNull(
        json['customer_plan_today'] ?? json['customerPlanToday'],
      ),
      gaOpeningStock: parseIntOr(
        json['ga_opening_stock'] ?? json['gaOpeningStock'],
      ),
      gaProductionToday: parseIntOr(
        json['ga_production_today'] ?? json['gaProductionToday'],
      ),
      warnings: (json['warnings'] is List)
          ? (json['warnings'] as List)
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
          : const [],
    );
  }

  /// True when every input required by the calculator is present
  /// and there are no blocking warnings — i.e. the row is ready to
  /// feed `DplDispatchCalculator.calculatePart(...)`.
  bool get isReady =>
      warnings.isEmpty &&
      bufferTargetAtTml != null &&
      trolleyCapacity != null &&
      tmlOpeningStock != null &&
      customerPlanToday != null;

  /// Build a `DispatchCalcInput` ready to feed the FE calculator.
  /// Caller must check [isReady] first; otherwise null inputs are
  /// coerced to 0 (calculator handles defensively but the result
  /// isn't meaningful).
  DispatchCalcInput toCalcInput() {
    return DispatchCalcInput(
      partId: partId,
      customerPn: customerPn,
      description: description,
      bufferTargetAtTml: bufferTargetAtTml ?? 0,
      trolleyCapacity: trolleyCapacity ?? 1,
      tmlOpeningStock: tmlOpeningStock ?? 0,
      customerPlanToday: customerPlanToday ?? 0,
      gaOpeningStock: gaOpeningStock,
      gaProductionToday: gaProductionToday,
      tripsPerDay: tripsPerDay ?? 6,
    );
  }
}

/// Full `GET /manager/dispatch-plan/inputs` response.
class DplDispatchPlanInputsPage {
  final String plantCode;
  final DateTime date;
  final List<DplDispatchPlanInputRow> parts;
  final List<String> globalWarnings;

  const DplDispatchPlanInputsPage({
    required this.plantCode,
    required this.date,
    this.parts = const [],
    this.globalWarnings = const [],
  });

  factory DplDispatchPlanInputsPage.fromJson(Map<String, dynamic> json) {
    return DplDispatchPlanInputsPage(
      plantCode: parseStringOr(json['plant_code'] ?? json['plantCode']),
      date: parseDateTimeOrNull(json['date']) ?? DateTime.now(),
      parts: (json['parts'] is List)
          ? (json['parts'] as List)
              .whereType<Map>()
              .map((e) => DplDispatchPlanInputRow.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList(growable: false)
          : const [],
      globalWarnings: (json['global_warnings'] is List)
          ? (json['global_warnings'] as List)
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList(growable: false)
          : const [],
    );
  }

  /// Parts that are ready to feed the calculator (no missing inputs).
  Iterable<DplDispatchPlanInputRow> get readyParts =>
      parts.where((p) => p.isReady);

  /// Parts that are blocked by at least one warning.
  Iterable<DplDispatchPlanInputRow> get blockedParts =>
      parts.where((p) => !p.isReady);
}
