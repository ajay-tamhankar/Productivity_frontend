import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_buffer_norm.dart';

/// Plant currently being edited on the Buffer Norms admin screen.
/// Pre-fills from whatever plant the Today's Plan screen had open so
/// the manager can flip between the two screens without re-picking.
final dplBufferNormsPlantProvider =
    NotifierProvider<DplBufferNormsPlantController, String?>(
  DplBufferNormsPlantController.new,
);

class DplBufferNormsPlantController extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? plantCode) => state = plantCode;
}

/// Raw `GET /manager/buffer-norms?plant_code=...` response. Re-fetches
/// when the plant changes or `ref.invalidate(...)` is called after a
/// successful save.
///
/// Returns null when no plant is picked — screen renders an empty-state
/// prompt in that case.
final dplBufferNormsPageProvider = FutureProvider.autoDispose<
    DplApiResponse<DplBufferNormsPage>?>((ref) async {
  final plantCode = ref.watch(dplBufferNormsPlantProvider);
  if (plantCode == null || plantCode.trim().isEmpty) return null;
  return ref.watch(dplApiServiceProvider).listBufferNorms(plantCode: plantCode);
});
