import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_supervisor_today.dart';

/// Polls `GET /manager/active-downtimes` every 30 seconds while a
/// manager-shell screen is mounted. Yields the current envelope on
/// every tick so the banner can react to opens/resumes coming from
/// the supervisor side.
final managerActiveDowntimesProvider = StreamProvider.autoDispose<
    DplApiResponse<List<ActiveDowntime>>>((ref) async* {
  final svc = ref.watch(dplApiServiceProvider);
  yield await svc.listManagerActiveDowntimes();

  final ticker =
      Stream<int>.periodic(const Duration(seconds: 30), (i) => i);
  await for (final _ in ticker) {
    yield await svc.listManagerActiveDowntimes();
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
