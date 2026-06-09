import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_supervisor_today.dart';

/// Polls `GET /manager/active-downtimes` every 30 seconds while a
/// manager-shell screen is mounted. Yields the current envelope on
/// every tick so the banner can react to opens/resumes coming from
/// the supervisor side.
///
/// DPL Customer fallback: the dedicated endpoint is manager-scoped on
/// the backend, so customer tokens get an empty / errored response.
/// When that happens we re-derive the same list from
/// `GET /manager/plans?date=today` — that route is reachable by the
/// customer (their Plans tab uses it) and each plan already embeds
/// its `active_downtime` row.
final managerActiveDowntimesProvider = StreamProvider.autoDispose<
    DplApiResponse<List<ActiveDowntime>>>((ref) async* {
  final svc = ref.watch(dplApiServiceProvider);

  Future<DplApiResponse<List<ActiveDowntime>>> fetch() async {
    final primary = await svc.listManagerActiveDowntimes();
    final hasRows = primary.isOk && (primary.data?.isNotEmpty ?? false);
    if (hasRows) return primary;

    // Fallback for roles (DPL_CUSTOMER) that can't hit the dedicated
    // endpoint: pull today's plans and harvest each plan's embedded
    // `active_downtime`. Keeps the same envelope shape so callers
    // don't have to branch.
    final today = DateTime.now();
    final plans = await svc.listPlans(
      date: DateTime(today.year, today.month, today.day),
    );
    if (plans.isOk && plans.data != null) {
      final derived = <ActiveDowntime>[];
      for (final plan in plans.data!) {
        final d = plan.activeDowntime;
        if (d == null) continue;
        // The plans response may not echo `machine_id` / `machine_name`
        // / `plan_id` inside the active_downtime sub-object — backfill
        // from the parent plan so the per-machine banner can match it.
        derived.add(ActiveDowntime(
          id: d.id,
          reasonName: d.reasonName,
          startTime: d.startTime,
          machineId: d.machineId ?? plan.machineId,
          machineName: d.machineName ?? plan.machineName,
          planId: d.planId ?? plan.id,
          planItemId: d.planItemId,
          supervisorUserId: d.supervisorUserId ?? plan.supervisorUserId,
          supervisorName: d.supervisorName ?? plan.supervisorName,
          shiftCode: d.shiftCode,
          category: d.category,
        ));
      }
      if (derived.isNotEmpty) return DplApiResponse.ok(derived);
    }
    return primary;
  }

  yield await fetch();

  final ticker =
      Stream<int>.periodic(const Duration(seconds: 30), (i) => i);
  await for (final _ in ticker) {
    yield await fetch();
  }
});

/// Single-row view used by the sticky red banner. Returns `null` when
/// no downtime is open (banner is hidden), or the newest open one
/// otherwise (server already orders rows newest-first).
final managerFirstActiveDowntimeProvider =
    Provider.autoDispose<ActiveDowntime?>((ref) {
  final async = ref.watch(managerActiveDowntimesProvider);
  final envelope = async.asData?.value;
  if (envelope == null || envelope.isError) return null;
  final list = envelope.data ?? const <ActiveDowntime>[];
  if (list.isEmpty) return null;
  return list.first;
});
