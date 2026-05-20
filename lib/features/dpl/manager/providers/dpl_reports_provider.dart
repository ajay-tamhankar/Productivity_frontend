import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
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
    final today = DateTime.now();
    return DplReportRange(
      from: DateTime(today.year, today.month, today.day - 6),
      to: DateTime(today.year, today.month, today.day),
    );
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
  return ref
      .watch(dplApiServiceProvider)
      .reportDowntime(from: r.from, to: r.to);
});

final dplSupervisorPerformanceReportProvider = FutureProvider.autoDispose<
    DplApiResponse<DplSupervisorPerformanceReport>>((ref) async {
  final r = ref.watch(dplReportRangeProvider);
  return ref
      .watch(dplApiServiceProvider)
      .reportSupervisorPerformance(from: r.from, to: r.to);
});

final dplPartWiseReportProvider = FutureProvider.autoDispose<
    DplApiResponse<DplPartWiseReport>>((ref) async {
  final r = ref.watch(dplReportRangeProvider);
  return ref
      .watch(dplApiServiceProvider)
      .reportPartWise(from: r.from, to: r.to);
});
