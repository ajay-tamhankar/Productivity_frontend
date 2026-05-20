import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently-selected bottom-nav tab on the DPL Manager shell.
///
/// Promoted to a provider (rather than local state in the shell) so that
/// the persistent [DplManagerFooter] mounted on nested screens can write
/// to it. Tapping a tab from a detail screen sets this and pops the
/// stack back to the shell — the shell then displays the requested tab.
final dplManagerTabProvider =
    NotifierProvider<DplManagerTabController, int>(
  DplManagerTabController.new,
);

class DplManagerTabController extends Notifier<int> {
  @override
  int build() => 0;

  /// Tab indices (matches the order in DplManagerFooter):
  /// 0 = Dashboard, 1 = Plans, 2 = Reports, 3 = Settings.
  void set(int index) {
    if (index < 0) return;
    state = index;
  }
}
