import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_production_plan.dart';
import '../../models/dpl_production_plan_item.dart';
import 'dpl_reports_provider.dart';

/// One row in the Daily Log report — a flattened combination of one
/// production-plan + one of its items. Computed fields (durations,
/// completion %) are derived from raw startTime/endTime/qty values.
class DplDailyLogRow {
  final DateTime planDate;
  final int planId;
  final int machineId;
  final String machineName;
  final String supervisorName;
  final int? itemId;
  final int? planNo;
  final String partLabel;
  final String shiftLabel;
  final String status;
  final int planQty;
  final int actualQty;
  final DateTime? startTime;
  final DateTime? endTime;
  /// Total downtime against this item in minutes (sum of paused durations).
  final int downtimeMinutes;
  final String reasonOrRemarks;

  const DplDailyLogRow({
    required this.planDate,
    required this.planId,
    required this.machineId,
    required this.machineName,
    required this.supervisorName,
    required this.partLabel,
    required this.shiftLabel,
    required this.status,
    required this.planQty,
    required this.actualQty,
    required this.startTime,
    required this.endTime,
    required this.downtimeMinutes,
    required this.reasonOrRemarks,
    this.itemId,
    this.planNo,
  });

  /// End − Start, in minutes. Null when the item never ran.
  int? get runMinutes {
    final s = startTime;
    final e = endTime;
    if (s == null || e == null) return null;
    final diff = e.difference(s).inMinutes;
    return diff < 0 ? 0 : diff;
  }

  /// Run minutes minus downtime, clamped to ≥ 0.
  int? get effectiveRunMinutes {
    final r = runMinutes;
    if (r == null) return null;
    final effective = r - downtimeMinutes;
    return effective < 0 ? 0 : effective;
  }

  double get completionPct =>
      planQty <= 0 ? 0 : (actualQty / planQty).clamp(0.0, 1.0);

  static DplDailyLogRow fromPlanItem({
    required DplProductionPlan plan,
    required DplProductionPlanItem item,
  }) {
    final part = [
      if (item.partNumber.trim().isNotEmpty) item.partNumber.trim(),
      if (item.partDescription.trim().isNotEmpty)
        item.partDescription.trim()
      else if (item.partName.trim().isNotEmpty)
        item.partName.trim(),
    ].join(' • ');

    String shiftLabel = (item.shiftCode ?? '').trim();
    if (shiftLabel.isEmpty && item.shiftId != null) {
      shiftLabel = '#${item.shiftId}';
    }
    if (shiftLabel.isEmpty) shiftLabel = '-';

    String reason = (item.remarks ?? '').trim();
    if (reason.isEmpty) reason = (plan.remarks ?? '').trim();

    return DplDailyLogRow(
      planDate: plan.planDate,
      planId: plan.id,
      machineId: plan.machineId,
      machineName: plan.machineName.isEmpty
          ? 'Machine #${plan.machineId}'
          : plan.machineName,
      supervisorName: plan.supervisorName,
      itemId: item.id,
      planNo: item.planNo,
      partLabel: part.isEmpty ? '-' : part,
      shiftLabel: shiftLabel,
      status: item.status,
      planQty: item.planQty,
      actualQty: item.actualQty,
      startTime: item.startTime,
      endTime: item.endTime,
      downtimeMinutes: item.totalPausedMinutes,
      reasonOrRemarks: reason.isEmpty ? '-' : reason,
    );
  }

  /// Synthetic row used when a plan has no items at all (e.g. header
  /// freshly created with no item rows yet). Lets the date appear in
  /// the report instead of being silently dropped.
  static DplDailyLogRow fromPlanWithoutItems(DplProductionPlan plan) {
    return DplDailyLogRow(
      planDate: plan.planDate,
      planId: plan.id,
      machineId: plan.machineId,
      machineName: plan.machineName.isEmpty
          ? 'Machine #${plan.machineId}'
          : plan.machineName,
      supervisorName: plan.supervisorName,
      partLabel: '-',
      shiftLabel: plan.shiftLabel.isEmpty ? '-' : plan.shiftLabel,
      status: plan.status,
      planQty: plan.totalPlanQty,
      actualQty: plan.totalActualQty,
      startTime: null,
      endTime: null,
      downtimeMinutes: 0,
      reasonOrRemarks: (plan.remarks ?? '').trim().isEmpty
          ? '-'
          : plan.remarks!.trim(),
    );
  }
}

class DplDailyLogReport {
  final List<DplDailyLogRow> rows;
  const DplDailyLogReport({required this.rows});
  factory DplDailyLogReport.empty() => const DplDailyLogReport(rows: []);

  bool get isEmpty => rows.isEmpty;
}

/// Daily Log report — fetches plans in the active report range and
/// flattens (plan × item) into one row per item. Falls back to a
/// per-plan `getPlan(id)` call whenever the list response omits items.
final dplDailyLogReportProvider =
    FutureProvider.autoDispose<DplApiResponse<DplDailyLogReport>>((ref) async {
  final range = ref.watch(dplReportRangeProvider);
  final api = ref.watch(dplApiServiceProvider);

  final listRes = await api.listPlans(
    from: range.from,
    to: range.to,
    machineId: range.machineId,
  );
  if (listRes.isError) {
    return DplApiResponse<DplDailyLogReport>.error(
      listRes.error ?? 'Failed to load plans.',
      code: listRes.code,
      statusCode: listRes.statusCode,
    );
  }

  final plans = listRes.data ?? const <DplProductionPlan>[];

  // Hydrate plans that came back without their items (the list
  // endpoint is allowed to omit them). We cap the number of detail
  // fetches so a huge date range doesn't melt the network — the
  // report is meant for shift/week reviews, not month-long pulls.
  const detailFetchCap = 60;
  final hydrated = <DplProductionPlan>[];
  var detailFetchCount = 0;
  for (final plan in plans) {
    if (plan.items.isNotEmpty || detailFetchCount >= detailFetchCap) {
      hydrated.add(plan);
      continue;
    }
    final detail = await api.getPlan(plan.id);
    detailFetchCount += 1;
    if (detail.isError || detail.data == null) {
      hydrated.add(plan);
      continue;
    }
    hydrated.add(detail.data!);
  }

  final rows = <DplDailyLogRow>[];
  for (final plan in hydrated) {
    if (plan.items.isEmpty) {
      rows.add(DplDailyLogRow.fromPlanWithoutItems(plan));
      continue;
    }
    for (final item in plan.items) {
      rows.add(DplDailyLogRow.fromPlanItem(plan: plan, item: item));
    }
  }

  rows.sort((a, b) {
    final byDate = a.planDate.compareTo(b.planDate);
    if (byDate != 0) return byDate;
    final byMachine = a.machineName.compareTo(b.machineName);
    if (byMachine != 0) return byMachine;
    return (a.planNo ?? 0).compareTo(b.planNo ?? 0);
  });

  return DplApiResponse<DplDailyLogReport>.ok(
    DplDailyLogReport(rows: rows),
  );
});
