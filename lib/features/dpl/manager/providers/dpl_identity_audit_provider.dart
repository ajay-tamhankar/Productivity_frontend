import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_identity.dart';

/// Filter values applied to the identity-verification audit list.
@immutable
class DplIdentityAuditFilters {
  final DateTime? from;
  final DateTime? to;
  final int? shiftId;
  final bool? flagged;
  final int page;
  final int limit;

  const DplIdentityAuditFilters({
    this.from,
    this.to,
    this.shiftId,
    this.flagged,
    this.page = 1,
    this.limit = 20,
  });

  DplIdentityAuditFilters copyWith({
    DateTime? from,
    bool fromIsNull = false,
    DateTime? to,
    bool toIsNull = false,
    int? shiftId,
    bool shiftIsNull = false,
    bool? flagged,
    bool flaggedIsNull = false,
    int? page,
    int? limit,
  }) {
    return DplIdentityAuditFilters(
      from: fromIsNull ? null : (from ?? this.from),
      to: toIsNull ? null : (to ?? this.to),
      shiftId: shiftIsNull ? null : (shiftId ?? this.shiftId),
      flagged: flaggedIsNull ? null : (flagged ?? this.flagged),
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }
}

/// Current filter state for the audit screen.
class DplIdentityAuditFiltersNotifier
    extends Notifier<DplIdentityAuditFilters> {
  @override
  DplIdentityAuditFilters build() => const DplIdentityAuditFilters();

  void setRange(DateTime? from, DateTime? to) {
    state = state.copyWith(
      from: from,
      fromIsNull: from == null,
      to: to,
      toIsNull: to == null,
      page: 1,
    );
  }

  void setShift(int? id) {
    state = state.copyWith(shiftId: id, shiftIsNull: id == null, page: 1);
  }

  void setFlagged(bool? flagged) {
    state = state.copyWith(
      flagged: flagged,
      flaggedIsNull: flagged == null,
      page: 1,
    );
  }

  void setPage(int page) => state = state.copyWith(page: page);

  void reset() => state = const DplIdentityAuditFilters();
}

final dplIdentityAuditFiltersProvider = NotifierProvider.autoDispose<
    DplIdentityAuditFiltersNotifier, DplIdentityAuditFilters>(
  DplIdentityAuditFiltersNotifier.new,
);

/// Paginated list driven by the filters above. Re-fires whenever a
/// filter changes (including page).
final dplIdentityAuditListProvider = FutureProvider.autoDispose<
    DplApiResponse<DplPagedResult<DplIdentityVerification>>>((ref) async {
  final f = ref.watch(dplIdentityAuditFiltersProvider);
  return ref.watch(dplApiServiceProvider).listIdentityVerifications(
        from: f.from,
        to: f.to,
        shiftId: f.shiftId,
        flagged: f.flagged,
        page: f.page,
        limit: f.limit,
      );
});

/// Photo bytes for a single verification, cached by id.
final dplIdentityPhotoProvider =
    FutureProvider.autoDispose.family<DplApiResponse<Uint8List>, int>(
  (ref, id) async {
    return ref.watch(dplApiServiceProvider).getManagerIdentityPhoto(id);
  },
);
