import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Active tab index for the Dispatch / QA / PDI shell. Hoisted into its
/// own provider (rather than local state) so the inbox-count badge in
/// the bottom nav can stay live when nested detail screens push routes
/// on top.
final dplSummaryTabProvider =
    NotifierProvider<DplSummaryTabController, int>(DplSummaryTabController.new);

class DplSummaryTabController extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}
