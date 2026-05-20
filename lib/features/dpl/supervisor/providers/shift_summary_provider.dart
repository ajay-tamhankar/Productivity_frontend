import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_shift_summary.dart';

/// Date the shift-summary screen is displaying. Locked to today by
/// default — the supervisor never needs to pick a different date.
final shiftSummaryDateProvider =
    NotifierProvider<ShiftSummaryDateController, DateTime>(
  ShiftSummaryDateController.new,
);

class ShiftSummaryDateController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

final shiftSummaryProvider = FutureProvider.autoDispose<
    DplApiResponse<DplShiftSummary>>((ref) async {
  final date = ref.watch(shiftSummaryDateProvider);
  return ref.watch(dplApiServiceProvider).shiftSummary(date);
});
