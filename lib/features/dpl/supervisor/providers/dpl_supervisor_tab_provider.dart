import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently-selected bottom-nav tab on the DPL Supervisor shell.
///
/// Promoted out of the shell's local state so the persistent
/// [DplSupervisorFooter] mounted on nested screens (MachinePlan,
/// PlanExecution) can switch tabs without losing state.
final dplSupervisorTabProvider =
    NotifierProvider<DplSupervisorTabController, int>(
  DplSupervisorTabController.new,
);

class DplSupervisorTabController extends Notifier<int> {
  @override
  int build() => 0;

  /// 0 = Today, 1 = Shift Summary, 2 = Profile.
  void set(int index) {
    if (index < 0) return;
    state = index;
  }
}
