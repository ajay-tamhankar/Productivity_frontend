import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_manpower_log.dart';

/// Filter state for the Manpower master screen.
class DplManpowerFilters {
  final DateTime? from;
  final DateTime? to;
  final int? shiftId;
  final int? machineId;

  const DplManpowerFilters({
    this.from,
    this.to,
    this.shiftId,
    this.machineId,
  });

  static const Object _sentinel = Object();

  DplManpowerFilters copyWith({
    Object? from = _sentinel,
    Object? to = _sentinel,
    Object? shiftId = _sentinel,
    Object? machineId = _sentinel,
  }) {
    return DplManpowerFilters(
      from: identical(from, _sentinel) ? this.from : from as DateTime?,
      to: identical(to, _sentinel) ? this.to : to as DateTime?,
      shiftId:
          identical(shiftId, _sentinel) ? this.shiftId : shiftId as int?,
      machineId: identical(machineId, _sentinel)
          ? this.machineId
          : machineId as int?,
    );
  }
}

final dplManpowerFiltersProvider =
    NotifierProvider<DplManpowerFiltersController, DplManpowerFilters>(
  DplManpowerFiltersController.new,
);

class DplManpowerFiltersController extends Notifier<DplManpowerFilters> {
  @override
  DplManpowerFilters build() {
    // Default to the current month.
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month, now.day);
    return DplManpowerFilters(from: from, to: to);
  }

  void update(DplManpowerFilters next) => state = next;
  void clear() => state = const DplManpowerFilters();
}

final dplManpowerProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplManpowerLog>>>((ref) async {
  final f = ref.watch(dplManpowerFiltersProvider);
  return ref.watch(dplApiServiceProvider).getManpower(
        from: f.from,
        to: f.to,
        shiftId: f.shiftId,
        machineId: f.machineId,
      );
});
