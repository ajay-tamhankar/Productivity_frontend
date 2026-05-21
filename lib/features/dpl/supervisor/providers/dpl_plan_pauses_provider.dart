import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_item_pause.dart';

/// Supervisor-side pause list, keyed by plan id.
final dplSupervisorPlanPausesProvider = FutureProvider.autoDispose
    .family<DplApiResponse<List<DplItemPause>>, int>((ref, planId) {
  return ref.read(dplApiServiceProvider).getSupervisorPlanPauses(planId);
});
