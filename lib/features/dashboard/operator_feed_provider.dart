import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/api_services/api_client.dart';
import '../../data/models/production_entry_model.dart';

part 'operator_feed_provider.g.dart';

class PaginatedFeedState {
  final List<ProductionEntryModel> entries;
  final int page;
  final bool hasMore;
  final bool isLoadingMore;

  PaginatedFeedState({
    required this.entries,
    required this.page,
    required this.hasMore,
    this.isLoadingMore = false,
  });

  PaginatedFeedState copyWith({
    List<ProductionEntryModel>? entries,
    int? page,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return PaginatedFeedState(
      entries: entries ?? this.entries,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

@riverpod
class OperatorFeedController extends _$OperatorFeedController {
  @override
  FutureOr<PaginatedFeedState> build() async {
    return _fetchPage(1);
  }

  Future<PaginatedFeedState> _fetchPage(int page) async {
    final client = ref.read(apiClientProvider);
    try {
      final response =
          await client.get('/production/operator-feed?page=$page&limit=10');
      final raw = response.data;

      // Handle array or paginated object structure robustly
      List<dynamic> dataList;
      if (raw is List) {
        dataList = raw;
      } else if (raw is Map && raw['data'] is List) {
        dataList = raw['data'] as List<dynamic>;
      } else if (raw is Map && raw['id'] != null) {
        dataList = [raw];
      } else {
        dataList = [];
      }

      final entries = dataList.map((j) => ProductionEntryModel.fromJson(j)).toList();
      
      // Determine if there are more
      bool hasMore = entries.length >= 10;
      if (raw is Map && raw['totalPages'] != null) {
        final totalPages = int.tryParse(raw['totalPages'].toString()) ?? page;
        hasMore = page < totalPages;
      }

      return PaginatedFeedState(
        entries: entries,
        page: page,
        hasMore: hasMore,
      );
    } catch (e) {
      throw Exception('Failed to load operator feed: $e');
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.hasError) return;
    
    final currentState = state.requireValue;
    if (!currentState.hasMore || currentState.isLoadingMore) return;

    state = AsyncValue.data(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = await _fetchPage(currentState.page + 1);
      
      state = AsyncValue.data(
        PaginatedFeedState(
          entries: [...currentState.entries, ...nextPage.entries],
          page: nextPage.page,
          hasMore: nextPage.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      // Revert loading more state on error, propagate to provider
      state = AsyncValue.data(currentState.copyWith(isLoadingMore: false));
      // Optionally could handle the error differently if we want to show a toast, 
      // but typically we can just leave it as is or set error State.
    }
  }
  
  Future<void> refresh() async {
     state = const AsyncValue.loading();
     state = await AsyncValue.guard(() => _fetchPage(1));
  }
}
