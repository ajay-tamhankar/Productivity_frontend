import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_dispatch_plan_actual.dart';

/// Dispatch **Plan vs Actual** report — the whole org breakdown in one
/// call. `autoDispose` so a fresh read is taken whenever the report screen
/// (or the plant-landing summary) mounts; the FE filters / sorts /
/// re-aggregates the rows client-side.
final dplDispatchPlanActualProvider = FutureProvider.autoDispose<
    DplApiResponse<DplDispatchPlanActualReport>>((ref) async {
  return ref.watch(dplApiServiceProvider).getDispatchPlanVsActual();
});
