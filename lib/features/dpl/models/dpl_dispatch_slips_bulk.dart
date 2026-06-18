import '_json_helpers.dart';
import 'dpl_dispatch_slip.dart';

/// One slip in the bulk-create payload to
/// `POST /api/v1/dpl/dispatch/slips/bulk`.
///
/// Same shape per slip as the single-slip create endpoint — only the
/// wrapper changes (an array under `slips` instead of one slip at the
/// root). Reuses [DispatchSlipItemRequest] so the per-line shape is
/// identical to the existing flow.
class DispatchSlipBulkItem {
  final String? vehicleNo;
  final String? notes;
  final List<DispatchSlipItemRequest> items;

  const DispatchSlipBulkItem({
    this.vehicleNo,
    this.notes,
    required this.items,
  });

  Map<String, dynamic> toJson() {
    return {
      if (vehicleNo != null && vehicleNo!.trim().isNotEmpty)
        'vehicle_no': vehicleNo!.trim(),
      if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      'items': [for (final it in items) it.toJson()],
    };
  }
}

/// Result of a bulk-create call. Atomic — either every slip created
/// or the whole transaction rolled back; the backend never returns
/// a partial success.
class DispatchSlipBulkResult {
  /// Number of slips actually persisted. Should equal the request's
  /// `slips.length` on success; on failure the request errored and
  /// this object is never built.
  final int createdCount;

  /// The fully-hydrated slips, in the same order as the request's
  /// `slips[]`. Each is the same shape returned by the single-slip
  /// create endpoint.
  final List<DplDispatchSlip> slips;

  const DispatchSlipBulkResult({
    required this.createdCount,
    this.slips = const [],
  });

  factory DispatchSlipBulkResult.fromJson(Map<String, dynamic> json) {
    return DispatchSlipBulkResult(
      createdCount: parseIntOr(json['created_count'] ?? json['createdCount']),
      slips: (json['slips'] is List)
          ? (json['slips'] as List)
              .whereType<Map>()
              .map((e) => DplDispatchSlip.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false)
          : const [],
    );
  }
}
