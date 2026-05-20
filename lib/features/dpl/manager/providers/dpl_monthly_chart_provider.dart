import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_monthly_chart.dart';

/// Date range for the Monthly Chart tab. Defaults to **current month**
/// (1st → today), which matches the company spreadsheet's MTD view.
class DplMonthlyChartRange {
  final DateTime from;
  final DateTime to;
  const DplMonthlyChartRange({required this.from, required this.to});
}

final dplMonthlyChartRangeProvider = NotifierProvider<
    DplMonthlyChartRangeController, DplMonthlyChartRange>(
  DplMonthlyChartRangeController.new,
);

class DplMonthlyChartRangeController
    extends Notifier<DplMonthlyChartRange> {
  @override
  DplMonthlyChartRange build() {
    final now = DateTime.now();
    return DplMonthlyChartRange(
      from: DateTime(now.year, now.month, 1),
      to: DateTime(now.year, now.month, now.day),
    );
  }

  void set(DplMonthlyChartRange range) => state = range;

  /// Convenience — jumps to a full named month (1st → last day).
  void setMonth(DateTime anyDayInMonth) {
    final first = DateTime(anyDayInMonth.year, anyDayInMonth.month, 1);
    final last = DateTime(anyDayInMonth.year, anyDayInMonth.month + 1, 0);
    state = DplMonthlyChartRange(from: first, to: last);
  }
}

final dplMonthlyChartProvider = FutureProvider.autoDispose<
    DplApiResponse<DplMonthlyChart>>((ref) async {
  final r = ref.watch(dplMonthlyChartRangeProvider);
  return ref
      .watch(dplApiServiceProvider)
      .reportDplChart(from: r.from, to: r.to);
});
