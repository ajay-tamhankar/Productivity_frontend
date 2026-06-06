import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_downtime_event_detail.dart';
import '../../models/dpl_reports.dart';

class DplReportRange {
  final DateTime? from;
  final DateTime? to;
  final int? machineId;

  const DplReportRange({this.from, this.to, this.machineId});

  static const Object _sentinel = Object();

  DplReportRange copyWith({
    Object? from = _sentinel,
    Object? to = _sentinel,
    Object? machineId = _sentinel,
  }) {
    return DplReportRange(
      from: identical(from, _sentinel) ? this.from : from as DateTime?,
      to: identical(to, _sentinel) ? this.to : to as DateTime?,
      machineId: identical(machineId, _sentinel)
          ? this.machineId
          : machineId as int?,
    );
  }
}

final dplReportRangeProvider =
    NotifierProvider<DplReportRangeController, DplReportRange>(
  DplReportRangeController.new,
);

class DplReportRangeController extends Notifier<DplReportRange> {
  @override
  DplReportRange build() {
    // Default to "all time → today" so the Downtime + Daily Log tabs
    // open with the full history visible. The user can still narrow
    // via the 7D / 30D / MTD chips or the date picker at the top.
    return const DplReportRange();
  }

  void set(DplReportRange range) => state = range;
}

final dplPlanVsActualReportProvider = FutureProvider.autoDispose<
    DplApiResponse<DplPlanVsActualReport>>((ref) async {
  final r = ref.watch(dplReportRangeProvider);
  return ref
      .watch(dplApiServiceProvider)
      .reportPlanVsActual(from: r.from, to: r.to, machineId: r.machineId);
});

final dplDowntimeReportProvider = FutureProvider.autoDispose<
    DplApiResponse<DplDowntimeReport>>((ref) async {
  final r = ref.watch(dplReportRangeProvider);
  return ref.watch(dplApiServiceProvider).reportDowntime(
        from: r.from,
        to: r.to,
        machineId: r.machineId,
      );
});

/// Same downtime report, aggregated per (day × reason). Drives the
/// combined date-wise view on the Downtime tab — each date card lists
/// its individual reasons with minutes and event counts.
final dplDowntimeByDateReportProvider = FutureProvider.autoDispose<
    DplApiResponse<DplDowntimeReport>>((ref) async {
  final r = ref.watch(dplReportRangeProvider);
  return ref.watch(dplApiServiceProvider).reportDowntime(
        from: r.from,
        to: r.to,
        machineId: r.machineId,
        groupBy: const ['day', 'reason'],
      );
});

/// Flat per-event downtime list with reason + remarks. Powers the
/// "Reason Matrix" segment on the Downtime tab.
final dplDowntimeEventsProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplDowntimeEventDetail>>>((ref) async {
  final r = ref.watch(dplReportRangeProvider);
  return ref.watch(dplApiServiceProvider).listDowntimeEvents(
        from: r.from,
        to: r.to,
        machineId: r.machineId,
      );
});

/// Which sub-view of the Downtime tab is currently active. Lifted to
/// the provider layer so the parent screen's AppBar download button
/// can route to the correct exporter without prop-drilling through
/// the segmented control.
enum DplDowntimeSubView { summary, reasonMatrix }

class DplDowntimeSubViewController extends Notifier<DplDowntimeSubView> {
  @override
  DplDowntimeSubView build() => DplDowntimeSubView.summary;

  void set(DplDowntimeSubView v) => state = v;
}

final dplDowntimeSubViewProvider =
    NotifierProvider<DplDowntimeSubViewController, DplDowntimeSubView>(
  DplDowntimeSubViewController.new,
);


final dplSupervisorPerformanceReportProvider = FutureProvider.autoDispose<
    DplApiResponse<DplSupervisorPerformanceReport>>((ref) async {
  final r = ref.watch(dplReportRangeProvider);
  return ref.watch(dplApiServiceProvider).reportSupervisorPerformance(
        from: r.from,
        to: r.to,
        machineId: r.machineId,
      );
});

final dplPartWiseReportProvider = FutureProvider.autoDispose<
    DplApiResponse<DplPartWiseReport>>((ref) async {
  final r = ref.watch(dplReportRangeProvider);
  return ref.watch(dplApiServiceProvider).reportPartWise(
        from: r.from,
        to: r.to,
        machineId: r.machineId,
      );
});
