import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_dashboard_summary.dart';
import '../../models/dpl_monthly_chart.dart';

/// Date currently shown on the Manager dashboard (defaults to today).
final dplDashboardDateProvider =
    NotifierProvider<DplDashboardDateController, DateTime>(
  DplDashboardDateController.new,
);

class DplDashboardDateController extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void set(DateTime date) {
    state = DateTime(date.year, date.month, date.day);
  }
}

/// Dashboard summary for the selected date. Re-fetches whenever the date
/// changes.
final dplDashboardSummaryProvider =
    FutureProvider.autoDispose<DplApiResponse<DplDashboardSummary>>(
        (ref) async {
  final date = ref.watch(dplDashboardDateProvider);
  final svc = ref.watch(dplApiServiceProvider);
  return svc.getDashboard(date);
});

/// Month-to-Date roll-up used by the dashboard KPI strip.
///
/// Calls the composite `/reports/dpl-chart` endpoint for the current
/// month (1st → today) and surfaces only the `cumulative` block.
///
/// The result includes plan / actual / achievement %, downtime, manhrs,
/// and lost manhrs — everything the strip cards need.
final dplDashboardMtdProvider = FutureProvider.autoDispose<
    DplApiResponse<DplMonthlyChart>>((ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, 1);
  final to = DateTime(now.year, now.month, now.day);
  return ref
      .watch(dplApiServiceProvider)
      .reportDplChart(from: from, to: to);
});
