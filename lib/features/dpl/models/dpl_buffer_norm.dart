import '_json_helpers.dart';

/// One row in the per-plant, per-part buffer-norms master data.
///
/// The Manager configures these once (or whenever the customer's
/// stocking norm changes). They feed the `DispatchCalcInput.bufferTargetAtTml`
/// / `trolleyCapacity` / `tripsPerDay` fields on the FE calculator.
///
/// Mirrors the response shape returned by
/// `GET /api/v1/dpl/manager/buffer-norms?plant_code=...`.
class DplBufferNorm {
  final int id;
  final int partId;

  /// Customer P/N — e.g. `546469500114ZY`. Display only.
  final String customerPn;

  /// Short description code — e.g. `114ZY`. Display only.
  final String description;

  /// Long part name — e.g. `NEXON PR HDL ASSY W BIG RLS C/O LLG,F`.
  /// Display only.
  final String partName;

  final int machineId;
  final String machineName;

  final int bufferTargetQty;
  final int trolleyCapacityQty;
  final int tripsPerDay;

  final DateTime? updatedAt;

  const DplBufferNorm({
    required this.id,
    required this.partId,
    this.customerPn = '',
    this.description = '',
    this.partName = '',
    required this.machineId,
    this.machineName = '',
    required this.bufferTargetQty,
    required this.trolleyCapacityQty,
    this.tripsPerDay = 6,
    this.updatedAt,
  });

  factory DplBufferNorm.fromJson(Map<String, dynamic> json) {
    return DplBufferNorm(
      id: parseIntOr(json['id']),
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      customerPn: parseStringOr(json['customer_pn'] ?? json['customerPn']),
      description: parseStringOr(json['description']),
      partName: parseStringOr(json['part_name'] ?? json['partName']),
      machineId: parseIntOr(json['machine_id'] ?? json['machineId']),
      machineName: parseStringOr(json['machine_name'] ?? json['machineName']),
      bufferTargetQty: parseIntOr(
        json['buffer_target_qty'] ?? json['bufferTargetQty'],
      ),
      trolleyCapacityQty: parseIntOr(
        json['trolley_capacity_qty'] ?? json['trolleyCapacityQty'],
      ),
      tripsPerDay: parseIntOr(
        json['trips_per_day'] ?? json['tripsPerDay'],
        6,
      ),
      updatedAt: parseDateTimeOrNull(json['updated_at'] ?? json['updatedAt']),
    );
  }
}

/// Compact reference to a part that doesn't have a buffer norm row yet.
/// Returned in the `parts_without_norms` block of the GET response so the
/// admin screen can highlight what's missing.
class DplBufferNormMissingPart {
  final int partId;
  final String customerPn;
  final String description;

  const DplBufferNormMissingPart({
    required this.partId,
    this.customerPn = '',
    this.description = '',
  });

  factory DplBufferNormMissingPart.fromJson(Map<String, dynamic> json) {
    return DplBufferNormMissingPart(
      partId: parseIntOr(json['part_id'] ?? json['partId']),
      customerPn: parseStringOr(json['customer_pn'] ?? json['customerPn']),
      description: parseStringOr(json['description']),
    );
  }
}

/// Full `GET /manager/buffer-norms` response.
class DplBufferNormsPage {
  final String plantCode;
  final List<DplBufferNorm> norms;
  final List<DplBufferNormMissingPart> partsWithoutNorms;

  const DplBufferNormsPage({
    required this.plantCode,
    this.norms = const [],
    this.partsWithoutNorms = const [],
  });

  factory DplBufferNormsPage.fromJson(Map<String, dynamic> json) {
    return DplBufferNormsPage(
      plantCode: parseStringOr(json['plant_code'] ?? json['plantCode']),
      norms: (json['norms'] is List)
          ? (json['norms'] as List)
              .whereType<Map>()
              .map((e) => DplBufferNorm.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
      partsWithoutNorms: (json['parts_without_norms'] is List)
          ? (json['parts_without_norms'] as List)
              .whereType<Map>()
              .map((e) => DplBufferNormMissingPart.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList(growable: false)
          : const [],
    );
  }
}

/// One row in the bulk-upsert payload to `PUT /manager/buffer-norms`.
class DplBufferNormUpsertRequest {
  final int partId;
  final int bufferTargetQty;
  final int trolleyCapacityQty;
  final int tripsPerDay;

  const DplBufferNormUpsertRequest({
    required this.partId,
    required this.bufferTargetQty,
    required this.trolleyCapacityQty,
    this.tripsPerDay = 6,
  });

  Map<String, dynamic> toJson() => {
        'part_id': partId,
        'buffer_target_qty': bufferTargetQty,
        'trolley_capacity_qty': trolleyCapacityQty,
        'trips_per_day': tripsPerDay,
      };
}
