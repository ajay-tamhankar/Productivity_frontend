import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_production_summary.dart';

/// Filter / search / sort state for the Production Summary screen.
///
/// Lives in its own Notifier so the screen can mutate individual fields
/// (search query, machine, date range) without rebuilding all of them.
class DplProductionSummaryFilters {
  final int? machineId;
  final int? partId;
  final String query;
  final DateTime? from;
  final DateTime? to;
  final bool onlyProduced;
  final String sort;
  final String order;
  final int page;
  final int limit;

  /// Plant scope (e.g. `NEXON_EV`). Set when the user drills into a
  /// plant from the landing screen; cleared when leaving plant scope.
  /// Backend rejects unknown codes with `INVALID_PLANT_CODE`.
  final String? plantCode;

  const DplProductionSummaryFilters({
    this.machineId,
    this.partId,
    this.query = '',
    this.from,
    this.to,
    this.onlyProduced = false,
    this.sort = 'last_produced_at',
    this.order = 'desc',
    this.page = 1,
    this.limit = 50,
    this.plantCode,
  });

  static const Object _sentinel = Object();

  DplProductionSummaryFilters copyWith({
    Object? machineId = _sentinel,
    Object? partId = _sentinel,
    Object? query = _sentinel,
    Object? from = _sentinel,
    Object? to = _sentinel,
    bool? onlyProduced,
    String? sort,
    String? order,
    int? page,
    int? limit,
    Object? plantCode = _sentinel,
  }) {
    return DplProductionSummaryFilters(
      machineId:
          identical(machineId, _sentinel) ? this.machineId : machineId as int?,
      partId: identical(partId, _sentinel) ? this.partId : partId as int?,
      query: identical(query, _sentinel) ? this.query : (query as String? ?? ''),
      from: identical(from, _sentinel) ? this.from : from as DateTime?,
      to: identical(to, _sentinel) ? this.to : to as DateTime?,
      onlyProduced: onlyProduced ?? this.onlyProduced,
      sort: sort ?? this.sort,
      order: order ?? this.order,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      plantCode: identical(plantCode, _sentinel)
          ? this.plantCode
          : plantCode as String?,
    );
  }

  /// Reset everything *except* sort + paging + plant scope — used by
  /// the "Clear" CTA in the filter sheet so the user keeps their sort
  /// preference. Plant stays sticky because the user is *in* that
  /// plant's view; the clear is just for the in-plant filters.
  DplProductionSummaryFilters clearedFilters() {
    return DplProductionSummaryFilters(
      sort: sort,
      order: order,
      limit: limit,
      plantCode: plantCode,
    );
  }

  bool get hasActiveFilters =>
      machineId != null ||
      partId != null ||
      query.trim().isNotEmpty ||
      from != null ||
      to != null ||
      onlyProduced;
}

final dplProductionSummaryFiltersProvider = NotifierProvider<
    DplProductionSummaryFiltersController,
    DplProductionSummaryFilters>(DplProductionSummaryFiltersController.new);

class DplProductionSummaryFiltersController
    extends Notifier<DplProductionSummaryFilters> {
  @override
  DplProductionSummaryFilters build() => const DplProductionSummaryFilters();

  void setQuery(String value) {
    state = state.copyWith(query: value, page: 1);
  }

  void setMachineId(int? id) {
    state = state.copyWith(machineId: id, page: 1);
  }

  void setPartId(int? id) {
    state = state.copyWith(partId: id, page: 1);
  }

  void setDateRange({DateTime? from, DateTime? to}) {
    state = state.copyWith(from: from, to: to, page: 1);
  }

  void setOnlyProduced(bool value) {
    state = state.copyWith(onlyProduced: value, page: 1);
  }

  void setSort(String sort, String order) {
    state = state.copyWith(sort: sort, order: order, page: 1);
  }

  void setPage(int page) {
    state = state.copyWith(page: page);
  }

  /// Pass `null` to leave the plant scope (e.g. on the landing screen
  /// or any non-plant-aware entry point).
  void setPlantCode(String? code) {
    state = state.copyWith(plantCode: code, page: 1);
  }

  void update(DplProductionSummaryFilters next) {
    state = next;
  }

  void clear() {
    state = state.clearedFilters();
  }
}

/// Page of summary buckets, refetched whenever any filter changes.
///
/// `autoDispose` so the cached state is dropped the moment the user
/// leaves the screen — the aggregate moves on every START/STOP and we
/// never want to render a stale snapshot.
final dplProductionSummaryProvider = FutureProvider.autoDispose<
    DplApiResponse<DplProductionSummaryPage>>((ref) async {
  final f = ref.watch(dplProductionSummaryFiltersProvider);
  return ref.watch(dplApiServiceProvider).listProductionSummary(
        plantCode: f.plantCode,
        machineId: f.machineId,
        partId: f.partId,
        q: f.query,
        from: f.from,
        to: f.to,
        onlyProduced: f.onlyProduced,
        sort: f.sort,
        order: f.order,
        page: f.page,
        limit: f.limit,
      );
});

/// Production summary scoped to one plant, family-keyed by plant code.
///
/// Each plant card on the landing screen reads its own bucket list
/// from this provider so it can populate the per-card machine /
/// description dropdowns. `limit: 200` is generous enough that all
/// produced buckets land in a single page (current Sanand JIT data
/// has ~10 buckets total). `autoDispose` so the cache drops when the
/// landing screen unmounts — buckets move on every START/STOP and
/// we never want to render a stale snapshot.
final dplProductionSummaryByPlantProvider = FutureProvider.autoDispose
    .family<DplApiResponse<DplProductionSummaryPage>, String>(
  (ref, plantCode) async {
    return ref.watch(dplApiServiceProvider).listProductionSummary(
          plantCode: plantCode,
          onlyProduced: true,
          limit: 200,
        );
  },
);
