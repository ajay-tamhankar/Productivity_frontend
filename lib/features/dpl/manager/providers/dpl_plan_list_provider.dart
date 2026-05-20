import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_production_plan.dart';

class DplPlanListFilters {
  final DateTime? from;
  final DateTime? to;
  final int? machineId;
  final int? supervisorUserId;
  final String? status;

  const DplPlanListFilters({
    this.from,
    this.to,
    this.machineId,
    this.supervisorUserId,
    this.status,
  });

  static const Object _sentinel = Object();

  DplPlanListFilters copyWith({
    Object? from = _sentinel,
    Object? to = _sentinel,
    Object? machineId = _sentinel,
    Object? supervisorUserId = _sentinel,
    Object? status = _sentinel,
  }) {
    return DplPlanListFilters(
      from: identical(from, _sentinel) ? this.from : from as DateTime?,
      to: identical(to, _sentinel) ? this.to : to as DateTime?,
      machineId: identical(machineId, _sentinel)
          ? this.machineId
          : machineId as int?,
      supervisorUserId: identical(supervisorUserId, _sentinel)
          ? this.supervisorUserId
          : supervisorUserId as int?,
      status:
          identical(status, _sentinel) ? this.status : status as String?,
    );
  }

  bool get isEmpty =>
      from == null &&
      to == null &&
      machineId == null &&
      supervisorUserId == null &&
      (status == null || status!.isEmpty);
}

final dplPlanListFiltersProvider =
    NotifierProvider<DplPlanListFiltersController, DplPlanListFilters>(
  DplPlanListFiltersController.new,
);

class DplPlanListFiltersController extends Notifier<DplPlanListFilters> {
  @override
  DplPlanListFilters build() => const DplPlanListFilters();

  void update(DplPlanListFilters next) => state = next;
  void clear() => state = const DplPlanListFilters();
}

final dplPlanListProvider = FutureProvider.autoDispose<
    DplApiResponse<List<DplProductionPlan>>>((ref) async {
  final f = ref.watch(dplPlanListFiltersProvider);
  return ref.watch(dplApiServiceProvider).listPlans(
        from: f.from,
        to: f.to,
        machineId: f.machineId,
        supervisorUserId: f.supervisorUserId,
        status: f.status,
      );
});
