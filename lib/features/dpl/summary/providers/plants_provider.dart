import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_plant.dart';

/// Loads the hardcoded 3-plant list from the backend once and keeps it
/// alive for the rest of the session — the mapping doesn't change at
/// runtime (server invariant) so re-fetching on every screen entry
/// would just burn bandwidth. Pull-to-refresh from the landing screen
/// can `ref.invalidate(dplPlantsProvider)` if needed.
final dplPlantsProvider =
    FutureProvider<DplApiResponse<List<DplPlant>>>((ref) async {
  return ref.watch(dplApiServiceProvider).listPlants();
});
