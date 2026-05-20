import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_downtime_reason.dart';
import '../../models/dpl_machine.dart';
import '../../models/dpl_part.dart';
import '../../models/dpl_supervisor.dart';

/// Machines — cached list. Use `ref.invalidate(dplMachinesProvider)` after
/// a mutation to force a reload.
final dplMachinesProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplMachine>>>((ref) async {
  return ref.watch(dplApiServiceProvider).getMachines();
});

/// Supervisors — cached, no-arg fetch. Used by the upload-plan dropdown.
final dplSupervisorsProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplSupervisor>>>((ref) async {
  return ref.watch(dplApiServiceProvider).getSupervisors();
});

/// Downtime reasons — cached list.
final dplDowntimeReasonsProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplDowntimeReason>>>((ref) async {
  return ref.watch(dplApiServiceProvider).getDowntimeReasons();
});

// ---------------------------------------------------------------------------
// Parts — paginated, searchable. Backed by a Notifier so we can drive
// "load more on scroll" + search debouncing.
// ---------------------------------------------------------------------------

class DplPartsState {
  final List<DplPart> items;
  final int page;
  final int limit;
  final int total;
  final String query;
  /// Optional machine-name filter (matches the backend's
  /// `?machine_name=` query param exactly — e.g. "Nexon SR", "X0HL").
  final String? machineName;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  const DplPartsState({
    this.items = const [],
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.query = '',
    this.machineName,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  bool get hasMore => items.length < total;

  DplPartsState copyWith({
    List<DplPart>? items,
    int? page,
    int? limit,
    int? total,
    String? query,
    Object? machineName = _sentinel,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error = _sentinel,
  }) {
    return DplPartsState(
      items: items ?? this.items,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      total: total ?? this.total,
      query: query ?? this.query,
      machineName: identical(machineName, _sentinel)
          ? this.machineName
          : machineName as String?,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

class DplPartsController extends AsyncNotifier<DplPartsState> {
  @override
  Future<DplPartsState> build() async {
    return _fetchFirstPage('', null);
  }

  Future<DplPartsState> _fetchFirstPage(
    String query,
    String? machineName,
  ) async {
    final svc = ref.read(dplApiServiceProvider);
    final res = await svc.getParts(
      q: query,
      machineName: machineName,
      page: 1,
      limit: 20,
    );
    if (res.isError) {
      return DplPartsState(
        query: query,
        machineName: machineName,
        error: res.error,
      );
    }
    final paged = res.data!;
    return DplPartsState(
      items: paged.items,
      page: paged.page,
      limit: paged.limit,
      total: paged.total,
      query: query,
      machineName: machineName,
    );
  }

  Future<void> setQuery(String query) async {
    final current = state.asData?.value;
    state = const AsyncValue<DplPartsState>.loading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(query, current?.machineName),
    );
  }

  Future<void> setMachineName(String? machineName) async {
    final current = state.asData?.value;
    state = const AsyncValue<DplPartsState>.loading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(current?.query ?? '', machineName),
    );
  }

  Future<void> refresh() async {
    final current = state.asData?.value;
    state = const AsyncValue<DplPartsState>.loading();
    state = await AsyncValue.guard(
      () => _fetchFirstPage(
        current?.query ?? '',
        current?.machineName,
      ),
    );
  }

  Future<void> loadMore() async {
    final current = state.asData?.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    try {
      final svc = ref.read(dplApiServiceProvider);
      final res = await svc.getParts(
        q: current.query,
        machineName: current.machineName,
        page: current.page + 1,
        limit: current.limit,
      );
      if (res.isError) {
        state = AsyncValue.data(current.copyWith(
          isLoadingMore: false,
          error: res.error,
        ));
        return;
      }
      final paged = res.data!;
      state = AsyncValue.data(current.copyWith(
        items: [...current.items, ...paged.items],
        page: paged.page,
        total: paged.total,
        isLoadingMore: false,
        error: null,
      ));
    } catch (e) {
      state = AsyncValue.data(current.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      ));
    }
  }
}

final dplPartsControllerProvider =
    AsyncNotifierProvider.autoDispose<DplPartsController, DplPartsState>(
  DplPartsController.new,
);

/// Args for the autocomplete search provider — needs both the typed
/// query and the optional machine scope so the same provider can serve
/// multiple call-sites (free search vs machine-scoped pickers).
class DplPartsSearchArgs {
  final String q;
  final String? machineName;

  const DplPartsSearchArgs({required this.q, this.machineName});

  @override
  bool operator ==(Object other) =>
      other is DplPartsSearchArgs &&
      other.q == q &&
      other.machineName == machineName;

  @override
  int get hashCode => Object.hash(q, machineName);
}

/// A small one-shot search used by the "Add Item" part autocomplete in the
/// Upload / Plan-detail screens. Kept separate from the paginated list so
/// typing in autocomplete doesn't clobber the masters screen state.
final dplPartsSearchProvider = FutureProvider.autoDispose
    .family<DplApiResponse<DplPagedResult<DplPart>>, DplPartsSearchArgs>(
        (ref, args) async {
  return ref.watch(dplApiServiceProvider).getParts(
        q: args.q,
        machineName: args.machineName,
        page: 1,
        limit: 25,
      );
});
