import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_downtime_reason.dart';

/// Cached downtime-reasons list for the entry sheet's dropdown.
final supervisorDowntimeReasonsProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplDowntimeReason>>>((ref) async {
  return ref.watch(dplApiServiceProvider).supervisorDowntimeReasons();
});
