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
    );
  }

  /// Reset everything *except* sort + paging — used by the "Clear" CTA
  /// in the filter sheet so the user keeps their sort preference.
  DplProductionSummaryFilters clearedFilters() {
    return DplProductionSummaryFilters(
      sort: sort,
      order: order,
      limit: limit,
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
