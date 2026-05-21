import '_json_helpers.dart';

/// One leftover item surfaced by
/// `GET /manager/plans/carry-forward-candidates`.
///
/// Used by the Upload Plan screen to auto-populate the new plan's
/// items list with unfinished work from previous shifts. When the
/// manager submits the plan, each kept candidate sends its
/// [sourceItemId] back as `carried_from_item_id` so the backend
/// links the new row to the source and removes it from future
/// candidate responses.
class DplCarryCandidate {
  final int sourceItemId;
  final int sourcePlanId;

  /// Plain "YYYY-MM-DD" wire form, kept as a DateTime for display.
  /// Backend returns the date-only form (no time component) per the
  /// contract — [DateTime.tryParse] handles it.
  final DateTime? sourcePlanDate;

  final String sourceShiftCode;
  final int partId;
  final String partNumber;
  final String partDescription;
  final String partName;
  final int sourcePlanQty;
  final int sourceActualQty;
  final int leftoverQty;

  const DplCarryCandidate({
    required this.sourceItemId,
    required this.sourcePlanId,
    required this.partId,
    required this.leftoverQty,
    this.sourcePlanDate,
    this.sourceShiftCode = '',
    this.partNumber = '',
    this.partDescription = '',
    this.partName = '',
    this.sourcePlanQty = 0,
    this.sourceActualQty = 0,
  });

  factory DplCarryCandidate.fromJson(Map<String, dynamic> json) {
    return DplCarryCandidate(
      sourceItemId: parseIntOr(
        json['source_item_id'] ?? json['sourceItemId'],
      ),
      sourcePlanId: parseIntOr(
        json['source_plan_id'] ?? json['sourcePlanId'],
      ),
      sourcePlanDate: parseDateTimeOrNull(
        json['source_plan_date'] ?? json['sourcePlanDate'],
      ),
      sourceShiftCode: parseStringOr(
        json['source_shift_code'] ?? json['sourceShiftCode'],
      ),
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      partNumber: parseStringOr(
        json['part_number'] ?? json['partNumber'],
      ),
      partDescription: parseStringOr(
        json['part_description'] ?? json['partDescription'],
      ),
      partName: parseStringOr(json['part_name'] ?? json['partName']),
      sourcePlanQty: parseIntOr(
        json['source_plan_qty'] ?? json['sourcePlanQty'],
      ),
      sourceActualQty: parseIntOr(
        json['source_actual_qty'] ?? json['sourceActualQty'],
      ),
      leftoverQty: parseIntOr(json['leftover_qty'] ?? json['leftoverQty']),
    );
  }
}
