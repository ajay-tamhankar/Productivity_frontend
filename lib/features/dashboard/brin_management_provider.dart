import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_services/api_client.dart';
import '../../data/models/production_entry_model.dart';

enum BrinSummaryRange { today, yesterday, thisWeek, thisMonth, all }

extension BrinSummaryRangeX on BrinSummaryRange {
  String get apiValue {
    switch (this) {
      case BrinSummaryRange.today:
        return 'today';
      case BrinSummaryRange.yesterday:
        return 'yesterday';
      case BrinSummaryRange.thisWeek:
        return 'thisWeek';
      case BrinSummaryRange.thisMonth:
        return 'thisMonth';
      case BrinSummaryRange.all:
        return 'all';
    }
  }

  String get label {
    switch (this) {
      case BrinSummaryRange.today:
        return 'Today';
      case BrinSummaryRange.yesterday:
        return 'Yesterday';
      case BrinSummaryRange.thisWeek:
        return 'This Week';
      case BrinSummaryRange.thisMonth:
        return 'This Month';
      case BrinSummaryRange.all:
        return 'All Time';
    }
  }
}

class BrinRcSummaryItem {
  final String rcNumber;
  final String? location;
  final String itemCode;
  final int totalActualQuantity;
  final int totalCorrectedQuantity;

  const BrinRcSummaryItem({
    required this.rcNumber,
    required this.location,
    required this.itemCode,
    required this.totalActualQuantity,
    required this.totalCorrectedQuantity,
  });

  factory BrinRcSummaryItem.fromJson(Map<String, dynamic> json) {
    return BrinRcSummaryItem(
      rcNumber: (json['rcNumber'] ?? '').toString(),
      location: json['location']?.toString(),
      itemCode: (json['itemCode'] ?? '').toString(),
      totalActualQuantity: _toInt(json['totalActualQuantity']),
      totalCorrectedQuantity: _toInt(json['totalCorrectedQuantity']),
    );
  }
}

class BrinManagementState {
  final String query;
  final String? activeRcNumber;
  final List<ProductionEntryModel> entries;
  final BrinSummaryRange summaryRange;
  final List<BrinRcSummaryItem> rcSummary;
  final bool isLoading;
  final bool isSummaryLoading;
  final bool isSubmitting;
  final String? errorMessage;
  final String? summaryErrorMessage;

  const BrinManagementState({
    this.query = '',
    this.activeRcNumber,
    this.entries = const [],
    this.summaryRange = BrinSummaryRange.all,
    this.rcSummary = const [],
    this.isLoading = false,
    this.isSummaryLoading = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.summaryErrorMessage,
  });

  BrinManagementState copyWith({
    String? query,
    String? activeRcNumber,
    List<ProductionEntryModel>? entries,
    BrinSummaryRange? summaryRange,
    List<BrinRcSummaryItem>? rcSummary,
    bool? isLoading,
    bool? isSummaryLoading,
    bool? isSubmitting,
    String? errorMessage,
    String? summaryErrorMessage,
    bool clearActiveRcNumber = false,
    bool clearError = false,
    bool clearSummaryError = false,
  }) {
    return BrinManagementState(
      query: query ?? this.query,
      activeRcNumber: clearActiveRcNumber
          ? null
          : (activeRcNumber ?? this.activeRcNumber),
      entries: entries ?? this.entries,
      summaryRange: summaryRange ?? this.summaryRange,
      rcSummary: rcSummary ?? this.rcSummary,
      isLoading: isLoading ?? this.isLoading,
      isSummaryLoading: isSummaryLoading ?? this.isSummaryLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      summaryErrorMessage: clearSummaryError
          ? null
          : (summaryErrorMessage ?? this.summaryErrorMessage),
    );
  }
}

class BrinManagementController extends Notifier<BrinManagementState> {
  @override
  BrinManagementState build() => const BrinManagementState();

  ApiClient get _client => ref.read(apiClientProvider);

  void setQuery(String value) {
    state = state.copyWith(query: value, clearError: true);
  }

  void clearSearch() {
    state = state.copyWith(
      query: '',
      entries: const [],
      clearActiveRcNumber: true,
      clearError: true,
    );
  }

  Future<void> fetchRcSummary({BrinSummaryRange? range}) async {
    final nextRange = range ?? state.summaryRange;
    state = state.copyWith(
      summaryRange: nextRange,
      isSummaryLoading: true,
      clearSummaryError: true,
    );

    try {
      final response = await _client.get(
        '/brin/rc-summary',
        queryParameters: {'range': nextRange.apiValue},
      );
      state = state.copyWith(
        summaryRange: nextRange,
        rcSummary: _parseRcSummary(response.data),
        isSummaryLoading: false,
        clearSummaryError: true,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        summaryRange: nextRange,
        isSummaryLoading: false,
        summaryErrorMessage: _extractApiMessage(
          e,
          'Failed to load RC-wise summary.',
        ),
      );
    } catch (e) {
      state = state.copyWith(
        summaryRange: nextRange,
        isSummaryLoading: false,
        summaryErrorMessage: 'Failed to load RC-wise summary: $e',
      );
    }
  }

  Future<void> searchByRcNumber([String? rcNumber]) async {
    final normalized = (rcNumber ?? state.query).trim();
    if (normalized.isEmpty) {
      state = state.copyWith(
        errorMessage: 'RC number is required.',
        entries: const [],
        clearActiveRcNumber: true,
      );
      return;
    }

    state = state.copyWith(
      query: normalized,
      activeRcNumber: normalized,
      isLoading: true,
      clearError: true,
    );

    try {
      final response = await _client.get(
        '/brin/rc/${Uri.encodeComponent(normalized)}',
      );
      final entries = _parseEntries(response.data);
      state = state.copyWith(
        entries: entries,
        isLoading: false,
        clearError: true,
      );
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        entries: const [],
        errorMessage: _extractApiMessage(e, 'Failed to load RC details.'),
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        entries: const [],
        errorMessage: 'Failed to load RC details: $e',
      );
    }
  }

  Future<void> updateLocation({
    required String rcNumber,
    required String location,
  }) async {
    final normalizedRc = rcNumber.trim();
    final normalizedLocation = location.trim();
    if (normalizedRc.isEmpty) {
      throw Exception('RC number is missing.');
    }
    if (normalizedLocation.isEmpty) {
      throw Exception('Location is required.');
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final response = await _client.patch(
        '/brin/rc/${Uri.encodeComponent(normalizedRc)}/location',
        data: {'location': normalizedLocation},
      );

      final updatedEntries = _parseEntries(response.data);
      if (updatedEntries.isNotEmpty) {
        state = state.copyWith(
          entries: updatedEntries,
          isSubmitting: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          entries: state.entries
              .map((entry) => entry.copyWith(location: normalizedLocation))
              .toList(),
          isSubmitting: false,
          clearError: true,
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _extractApiMessage(e, 'Failed to update RC location.'),
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to update RC location: $e',
      );
      rethrow;
    }
  }

  Future<void> updateQuantity({
    required String entryId,
    required int quantity,
    required String comment,
  }) async {
    final normalizedId = entryId.trim();
    final normalizedComment = comment.trim();
    if (normalizedId.isEmpty) {
      throw Exception('Entry ID is missing.');
    }
    if (quantity < 0) {
      throw Exception('Quantity cannot be negative.');
    }
    if (normalizedComment.isEmpty) {
      throw Exception('Comment is required.');
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final response = await _client.patch(
        '/brin/entries/$normalizedId/quantity',
        data: {'quantity': quantity, 'comment': normalizedComment},
      );

      final updatedEntry = _parseEntry(response.data);
      if (updatedEntry != null) {
        state = state.copyWith(
          entries: [
            for (final entry in state.entries)
              if (entry.id == normalizedId) updatedEntry else entry,
          ],
          isSubmitting: false,
          clearError: true,
        );
      } else {
        state = state.copyWith(
          entries: [
            for (final entry in state.entries)
              if (entry.id == normalizedId)
                entry.copyWith(actualQuantity: quantity)
              else
                entry,
          ],
          isSubmitting: false,
          clearError: true,
        );
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: _extractApiMessage(e, 'Failed to update quantity.'),
      );
      rethrow;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Failed to update quantity: $e',
      );
      rethrow;
    }
  }

  List<BrinRcSummaryItem> _parseRcSummary(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) => BrinRcSummaryItem.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();
    }

    if (data is Map) {
      final wrapped = data['data'];
      if (wrapped is List) {
        return wrapped
            .whereType<Map>()
            .map(
              (item) => BrinRcSummaryItem.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
    }

    return const [];
  }

  List<ProductionEntryModel> _parseEntries(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map(
            (item) =>
                ProductionEntryModel.fromJson(Map<String, dynamic>.from(item)),
          )
          .toList();
    }

    if (data is Map) {
      final wrapped = data['data'];
      if (wrapped is List) {
        return wrapped
            .whereType<Map>()
            .map(
              (item) => ProductionEntryModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      }
      if (wrapped is Map) {
        return [
          ProductionEntryModel.fromJson(Map<String, dynamic>.from(wrapped)),
        ];
      }
      if (data['id'] != null) {
        return [ProductionEntryModel.fromJson(Map<String, dynamic>.from(data))];
      }
    }

    return const [];
  }

  ProductionEntryModel? _parseEntry(dynamic data) {
    final entries = _parseEntries(data);
    if (entries.isNotEmpty) return entries.first;
    return null;
  }

  String _extractApiMessage(DioException error, String fallback) {
    final data = error.response?.data;
    if (data is Map) {
      final message = data['message']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return fallback;
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '0') ?? 0;
}

final brinManagementControllerProvider =
    NotifierProvider<BrinManagementController, BrinManagementState>(
      BrinManagementController.new,
    );
