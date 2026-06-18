import '_json_helpers.dart';

/// Compact actor reference for the "entered by" block on a snapshot.
class DplCustomerSnapshotActor {
  final int userId;
  final String name;

  const DplCustomerSnapshotActor({required this.userId, this.name = ''});

  factory DplCustomerSnapshotActor.fromJson(Map<String, dynamic> json) {
    return DplCustomerSnapshotActor(
      userId: parseIntOr(json['user_id'] ?? json['userId']),
      name: parseStringOr(json['name']),
    );
  }
}

/// One row in the per-plant, per-date daily customer snapshot.
///
/// Manager / Dispatch enters these each morning. They feed
/// `DispatchCalcInput.tmlOpeningStock` / `customerPlanToday` on the
/// FE calculator.
///
/// Mirrors `GET /api/v1/dpl/manager/customer-snapshots?...`.
class DplCustomerSnapshot {
  final int id;
  final int partId;

  final String customerPn;
  final String description;

  final int tmlOpeningStock;
  final int customerPlanQty;
  final String? remarks;

  final DplCustomerSnapshotActor? enteredBy;
  final DateTime? enteredAt;

  const DplCustomerSnapshot({
    required this.id,
    required this.partId,
    this.customerPn = '',
    this.description = '',
    required this.tmlOpeningStock,
    required this.customerPlanQty,
    this.remarks,
    this.enteredBy,
    this.enteredAt,
  });

  factory DplCustomerSnapshot.fromJson(Map<String, dynamic> json) {
    final rawBy = json['entered_by'] ?? json['enteredBy'];
    return DplCustomerSnapshot(
      id: parseIntOr(json['id']),
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      customerPn: parseStringOr(json['customer_pn'] ?? json['customerPn']),
      description: parseStringOr(json['description']),
      tmlOpeningStock: parseIntOr(
        json['tml_opening_stock'] ?? json['tmlOpeningStock'],
      ),
      customerPlanQty: parseIntOr(
        json['customer_plan_qty'] ?? json['customerPlanQty'],
      ),
      remarks: json['remarks'] is String ? json['remarks'] as String : null,
      enteredBy: rawBy is Map
          ? DplCustomerSnapshotActor.fromJson(Map<String, dynamic>.from(rawBy))
          : null,
      enteredAt: parseDateTimeOrNull(json['entered_at'] ?? json['enteredAt']),
    );
  }
}

/// Compact reference to a part that has a buffer norm but no snapshot
/// for the requested date yet.
class DplCustomerSnapshotMissingPart {
  final int partId;
  final String customerPn;
  final String description;

  const DplCustomerSnapshotMissingPart({
    required this.partId,
    this.customerPn = '',
    this.description = '',
  });

  factory DplCustomerSnapshotMissingPart.fromJson(Map<String, dynamic> json) {
    return DplCustomerSnapshotMissingPart(
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      customerPn: parseStringOr(json['customer_pn'] ?? json['customerPn']),
      description: parseStringOr(json['description']),
    );
  }
}

/// Full `GET /manager/customer-snapshots` response.
class DplCustomerSnapshotsPage {
  final String plantCode;
  final DateTime snapshotDate;
  final List<DplCustomerSnapshot> entries;
  final List<DplCustomerSnapshotMissingPart> missingParts;

  const DplCustomerSnapshotsPage({
    required this.plantCode,
    required this.snapshotDate,
    this.entries = const [],
    this.missingParts = const [],
  });

  factory DplCustomerSnapshotsPage.fromJson(Map<String, dynamic> json) {
    return DplCustomerSnapshotsPage(
      plantCode: parseStringOr(json['plant_code'] ?? json['plantCode']),
      snapshotDate: parseDateTimeOrNull(
            json['snapshot_date'] ?? json['snapshotDate'],
          ) ??
          DateTime.now(),
      entries: (json['entries'] is List)
          ? (json['entries'] as List)
              .whereType<Map>()
              .map((e) =>
                  DplCustomerSnapshot.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
      missingParts: (json['missing_parts'] is List)
          ? (json['missing_parts'] as List)
              .whereType<Map>()
              .map((e) => DplCustomerSnapshotMissingPart.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}

/// One row in the bulk-upsert payload to `POST /manager/customer-snapshots`.
class DplCustomerSnapshotUpsertRequest {
  final int partId;
  final int tmlOpeningStock;
  final int customerPlanQty;
  final String? remarks;

  const DplCustomerSnapshotUpsertRequest({
    required this.partId,
    required this.tmlOpeningStock,
    required this.customerPlanQty,
    this.remarks,
  });

  Map<String, dynamic> toJson() => {
        'part_id': partId,
        'tml_opening_stock': tmlOpeningStock,
        'customer_plan_qty': customerPlanQty,
        if (remarks != null && remarks!.trim().isNotEmpty)
          'remarks': remarks!.trim(),
      };
}
