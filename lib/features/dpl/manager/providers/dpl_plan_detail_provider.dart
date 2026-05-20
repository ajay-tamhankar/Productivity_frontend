import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_production_plan.dart';

/// Loads a single plan by id. Mutations (add item, update item, lock,
/// delete) should call the service directly and then
/// `ref.invalidate(dplPlanDetailProvider(id))`.
final dplPlanDetailProvider = FutureProvider.autoDispose
    .family<DplApiResponse<DplProductionPlan>, int>((ref, id) async {
  return ref.watch(dplApiServiceProvider).getPlan(id);
});
