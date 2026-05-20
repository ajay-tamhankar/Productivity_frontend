import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_supervisor_today.dart';

/// Stream-based provider that calls `GET /supervisor/today` immediately
/// and then re-polls every 30 seconds for as long as the dashboard is
/// mounted. Auto-dispose stops the timer when the screen leaves.
final todayPlansProvider = StreamProvider.autoDispose<
    DplApiResponse<SupervisorTodayResponse>>((ref) async* {
  final svc = ref.watch(dplApiServiceProvider);
  yield await svc.supervisorToday();

  final ticker = Stream<int>.periodic(const Duration(seconds: 30), (i) => i);
  await for (final _ in ticker) {
    yield await svc.supervisorToday();
  }
});

/// Derived provider — the FIRST active downtime across all of today's
/// plans, used by the global banner. Returns null when no downtime is
/// active.
final activeDowntimeProvider =
    Provider.autoDispose<ActiveDowntime?>((ref) {
  final today = ref.watch(todayPlansProvider).asData?.value;
  if (today == null || today.isError || today.data == null) return null;
  for (final plan in today.data!.plans) {
    if (plan.activeDowntime != null) return plan.activeDowntime;
  }
  return null;
});
