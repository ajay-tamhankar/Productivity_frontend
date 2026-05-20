import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_shift.dart';

/// Shifts master — cached list of active shifts by default. Use
/// `ref.invalidate(dplShiftsProvider)` after a CRUD mutation.
final dplShiftsProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplShift>>>((ref) async {
  return ref.watch(dplApiServiceProvider).getShifts();
});

/// Shifts master including soft-deleted rows — used by the Shifts CRUD
/// screen so admins can resurrect a previously-deleted shift.
final dplShiftsIncludeInactiveProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplShift>>>((ref) async {
  return ref
      .watch(dplApiServiceProvider)
      .getShifts(includeInactive: true);
});
