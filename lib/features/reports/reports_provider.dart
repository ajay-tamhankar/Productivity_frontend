import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:dio/dio.dart';
import '../../data/api_services/api_client.dart';
import '../../data/models/production_entry_model.dart';

part 'reports_provider.g.dart';

class ReportsState {
  final List<ProductionEntryModel> entries;
  final int totalCount;
  final bool isLoading;
  final Map<String, dynamic> filters;
  final int currentPage;
  final int pageSize;

  ReportsState({
    required this.entries,
    required this.totalCount,
    this.isLoading = false,
    this.filters = const {},
    this.currentPage = 0,
    this.pageSize = 10,
  });

  ReportsState copyWith({
    List<ProductionEntryModel>? entries,
    int? totalCount,
    bool? isLoading,
    Map<String, dynamic>? filters,
    int? currentPage,
    int? pageSize,
  }) {
    return ReportsState(
      entries: entries ?? this.entries,
      totalCount: totalCount ?? this.totalCount,
      isLoading: isLoading ?? this.isLoading,
      filters: filters ?? this.filters,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

@riverpod
class ReportsController extends _$ReportsController {
  @override
  ReportsState build() {
    // Initial fetch happens from the screen.
    return ReportsState(entries: [], totalCount: 0);
  }

  void updateFilters(Map<String, dynamic> newFilters) {
    state = state.copyWith(
      filters: newFilters,
      entries: [],
      totalCount: 0,
      currentPage: 0,
    );
  }

  Future<void> fetchPage(int pageIndex, int pageSize) async {
    // Page index is 0-based for Datatable, but API is usually 1-based
    final apiPage = pageIndex + 1;
    final apiLimit = pageSize.clamp(1, 100).toInt();
    state = state.copyWith(isLoading: true);

    try {
      final client = ref.read(apiClientProvider);

      final Map<String, dynamic> queryParams = {
        'page': apiPage,
        'limit': apiLimit,
        ...state.filters,
      };

      final response = await client.get(
        '/reports/detailed',
        queryParameters: queryParams,
      );

      // The provider can be disposed while the request is in flight
      // (e.g. the user switches tabs). Skip any further work in that case
      // so we don't poke a disposed Ref.
      if (!ref.mounted) return;

      List<dynamic> dataList = [];
      int totalCount = 0;

      if (response.data is Map) {
        dataList = response.data['data'] ?? [];
        totalCount = response.data['totalRecords'] ?? dataList.length;
      } else if (response.data is List) {
        dataList = response.data;
        totalCount = dataList.length;
      }

      final newEntries = dataList
          .map((j) => ProductionEntryModel.fromJson(j))
          .toList();

      state = state.copyWith(
        entries: newEntries,
        totalCount: totalCount,
        isLoading: false,
        currentPage: pageIndex,
        pageSize: apiLimit,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false);
      throw Exception('Failed to load reports: $e');
    }
  }

  Future<void> updateEntry({
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    if (id.trim().isEmpty) {
      throw Exception('Entry ID is missing.');
    }
    if (payload.isEmpty) {
      throw Exception('No changes provided.');
    }

    try {
      final client = ref.read(apiClientProvider);
      await client.patch('/production/entries/$id', data: payload);
    } on DioException catch (e) {
      final data = e.response?.data;
      final apiMessage = data is Map ? data['message']?.toString() : null;
      throw Exception(apiMessage ?? 'Failed to update production entry.');
    } catch (e) {
      throw Exception('Failed to update production entry: $e');
    }
  }
}
