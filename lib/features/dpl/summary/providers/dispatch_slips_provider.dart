import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../core/dpl_constants.dart';
import '../../models/dpl_dispatch_slip.dart';

/// Filter state for the Dispatch Slip Inbox / List screen.
///
/// The same Notifier serves all three "summary-only" roles — the
/// backend handles the role gating, we just decide which `status` to
/// pre-select when each role lands on its inbox.
class DplDispatchSlipFilters {
  /// Optional status filter — e.g. `pending_qa` for the QA inbox.
  final String? status;
  final int? machineId;
  final int? partId;
  final String query;
  final DateTime? from;
  final DateTime? to;
  final int page;
  final int limit;

  const DplDispatchSlipFilters({
    this.status,
    this.machineId,
    this.partId,
    this.query = '',
    this.from,
    this.to,
    this.page = 1,
    this.limit = 50,
  });

  static const Object _sentinel = Object();

  DplDispatchSlipFilters copyWith({
    Object? status = _sentinel,
    Object? machineId = _sentinel,
    Object? partId = _sentinel,
    Object? query = _sentinel,
    Object? from = _sentinel,
    Object? to = _sentinel,
    int? page,
    int? limit,
  }) {
    return DplDispatchSlipFilters(
      status: identical(status, _sentinel) ? this.status : status as String?,
      machineId:
          identical(machineId, _sentinel) ? this.machineId : machineId as int?,
      partId: identical(partId, _sentinel) ? this.partId : partId as int?,
      query: identical(query, _sentinel)
          ? this.query
          : (query as String? ?? ''),
      from: identical(from, _sentinel) ? this.from : from as DateTime?,
      to: identical(to, _sentinel) ? this.to : to as DateTime?,
      page: page ?? this.page,
      limit: limit ?? this.limit,
    );
  }

  bool get hasActiveFilters =>
      (status != null && status!.isNotEmpty) ||
      machineId != null ||
      partId != null ||
      query.trim().isNotEmpty ||
      from != null ||
      to != null;
}

final dplDispatchSlipFiltersProvider = NotifierProvider<
    DplDispatchSlipFiltersController,
    DplDispatchSlipFilters>(DplDispatchSlipFiltersController.new);

class DplDispatchSlipFiltersController
    extends Notifier<DplDispatchSlipFilters> {
  @override
  DplDispatchSlipFilters build() => const DplDispatchSlipFilters();

  void setStatus(String? status) {
    state = state.copyWith(status: status, page: 1);
  }

  void setQuery(String value) {
    state = state.copyWith(query: value, page: 1);
  }

  void setMachineId(int? id) {
    state = state.copyWith(machineId: id, page: 1);
  }

  void setDateRange({DateTime? from, DateTime? to}) {
    state = state.copyWith(from: from, to: to, page: 1);
  }

  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  void update(DplDispatchSlipFilters next) {
    state = next;
  }

  void clear() {
    state = DplDispatchSlipFilters(status: state.status, limit: state.limit);
  }
}

/// Paginated list of slips driven by the current filters. `autoDispose`
/// so the inbox doesn't keep a stale snapshot once the user navigates
/// away — every state move on the backend (approve/reject) needs a fresh
/// read on the next visit.
final dplDispatchSlipsProvider = FutureProvider.autoDispose<
    DplApiResponse<DplDispatchSlipPage>>((ref) async {
  final f = ref.watch(dplDispatchSlipFiltersProvider);
  return ref.watch(dplApiServiceProvider).listDispatchSlips(
        status: f.status,
        machineId: f.machineId,
        partId: f.partId,
        q: f.query,
        from: f.from,
        to: f.to,
        page: f.page,
        limit: f.limit,
      );
});

/// Single-slip detail fetched on demand by the printable detail screen.
/// Family-keyed by slip id so each opened slip has its own cache slot;
/// `autoDispose` so the cache is dropped when the screen closes.
final dplDispatchSlipDetailProvider = FutureProvider.autoDispose
    .family<DplApiResponse<DplDispatchSlip>, int>((ref, id) async {
  return ref.watch(dplApiServiceProvider).getDispatchSlip(id);
});

/// Compound key for [dplBucketSlipsProvider]. Records work as family
/// keys (Dart 3+) and give us a typed shape better than `String`.
typedef DplBucketKey = ({int machineId, int partId});

/// All slips for one specific `(machine, part)` bucket — fuels the
/// drill-in Bucket Detail screen. Backend already supports the
/// machine_id + part_id filter; we just call it with a higher limit so
/// the user can see the bucket's full history in one go.
final dplBucketSlipsProvider = FutureProvider.autoDispose
    .family<DplApiResponse<DplDispatchSlipPage>, DplBucketKey>(
  (ref, key) async {
    return ref.watch(dplApiServiceProvider).listDispatchSlips(
          machineId: key.machineId,
          partId: key.partId,
          limit: 200,
        );
  },
);

/// One status's contribution to a bucket — both how many slips sit in
/// that status AND the rolled-up qty across them. Lets the chip render
/// "3 Dispatched · 152" without an extra round-trip.
class DplStatusSlipQty {
  final int count;
  final int qty;

  const DplStatusSlipQty({this.count = 0, this.qty = 0});

  bool get hasAny => count > 0;

  DplStatusSlipQty add(int slipQty) =>
      DplStatusSlipQty(count: count + 1, qty: qty + slipQty);
}

/// Per-bucket pipeline snapshot — for each `(machine, part)` bucket,
/// the user's slips broken down by status with both count and qty.
/// Drives the chip strip on the Production Summary cards so Dispatch
/// can see the pipeline state — and the qty already committed — of a
/// bucket without leaving the screen.
class DplBucketSlipCounts {
  final DplStatusSlipQty pendingQa;
  final DplStatusSlipQty pendingDeo;
  final DplStatusSlipQty pendingPdi;
  final DplStatusSlipQty approved;
  final DplStatusSlipQty dispatched;
  final DplStatusSlipQty rejected;

  const DplBucketSlipCounts({
    this.pendingQa = const DplStatusSlipQty(),
    this.pendingDeo = const DplStatusSlipQty(),
    this.pendingPdi = const DplStatusSlipQty(),
    this.approved = const DplStatusSlipQty(),
    this.dispatched = const DplStatusSlipQty(),
    this.rejected = const DplStatusSlipQty(),
  });

  int get totalCount =>
      pendingQa.count +
      pendingDeo.count +
      pendingPdi.count +
      approved.count +
      dispatched.count +
      rejected.count;

  bool get hasAny => totalCount > 0;
  bool get hasOpen =>
      pendingQa.hasAny || pendingDeo.hasAny || pendingPdi.hasAny;

  DplBucketSlipCounts _bumpFor(String status, int slipQty) {
    switch (status) {
      case DplDispatchSlipStatus.pendingQa:
        return DplBucketSlipCounts(
          pendingQa: pendingQa.add(slipQty),
          pendingDeo: pendingDeo,
          pendingPdi: pendingPdi,
          approved: approved,
          dispatched: dispatched,
          rejected: rejected,
        );
      case DplDispatchSlipStatus.pendingDeo:
        return DplBucketSlipCounts(
          pendingQa: pendingQa,
          pendingDeo: pendingDeo.add(slipQty),
          pendingPdi: pendingPdi,
          approved: approved,
          dispatched: dispatched,
          rejected: rejected,
        );
      case DplDispatchSlipStatus.pendingPdi:
        return DplBucketSlipCounts(
          pendingQa: pendingQa,
          pendingDeo: pendingDeo,
          pendingPdi: pendingPdi.add(slipQty),
          approved: approved,
          dispatched: dispatched,
          rejected: rejected,
        );
      case DplDispatchSlipStatus.approved:
        return DplBucketSlipCounts(
          pendingQa: pendingQa,
          pendingDeo: pendingDeo,
          pendingPdi: pendingPdi,
          approved: approved.add(slipQty),
          dispatched: dispatched,
          rejected: rejected,
        );
      case DplDispatchSlipStatus.dispatched:
        return DplBucketSlipCounts(
          pendingQa: pendingQa,
          pendingDeo: pendingDeo,
          pendingPdi: pendingPdi,
          approved: approved,
          dispatched: dispatched.add(slipQty),
          rejected: rejected,
        );
      case DplDispatchSlipStatus.rejected:
        return DplBucketSlipCounts(
          pendingQa: pendingQa,
          pendingDeo: pendingDeo,
          pendingPdi: pendingPdi,
          approved: approved,
          dispatched: dispatched,
          rejected: rejected.add(slipQty),
        );
      default:
        return this;
    }
  }
}

String dplBucketKey(int machineId, int partId) => '$machineId|$partId';

/// Aggregates the visible page of the user's slips into a `(machine,
/// part) → counts` map. Used by the Dispatch role on the Production
/// Summary cards.
///
/// We pull a single page with a generous limit (200) and accept that
/// long-tailed accounts may not see every historical slip on the chip
/// strip — the data is illustrative, not authoritative. The full picture
/// always lives on the Slips tab.
final dplBucketSlipCountsProvider = FutureProvider.autoDispose<
    Map<String, DplBucketSlipCounts>>((ref) async {
  final res =
      await ref.watch(dplApiServiceProvider).listDispatchSlips(limit: 200);
  if (res.isError || res.data == null) {
    return const <String, DplBucketSlipCounts>{};
  }
  final out = <String, DplBucketSlipCounts>{};
  for (final s in res.data!.items) {
    final key = dplBucketKey(s.machineId, s.partId);
    final cur = out[key] ?? const DplBucketSlipCounts();
    out[key] = cur._bumpFor(s.status, s.qty);
  }
  return out;
});
