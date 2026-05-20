import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_downtime_event.dart';
import '../../models/dpl_supervisor_plan_detail.dart';

/// Per-plan provider keyed by planId. The detail screen + the plan-execution
/// screen both watch this so they stay in sync after a start/stop/downtime.
final machinePlanProvider = FutureProvider.autoDispose
    .family<DplApiResponse<DplSupervisorPlanDetail>, int>((ref, planId) async {
  return ref.watch(dplApiServiceProvider).supervisorGetPlan(planId);
});

/// Downtime history list for a plan.
final planDowntimesProvider = FutureProvider.autoDispose
    .family<DplApiResponse<List<DplDowntimeEvent>>, int>((ref, planId) async {
  return ref.watch(dplApiServiceProvider).listPlanDowntimes(planId);
});
