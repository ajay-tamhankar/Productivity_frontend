import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_carry_candidate.dart';

/// Key for [dplCarryCandidatesProvider]. Encapsulates the machine +
/// optional target date so Riverpod's `.family` can identity-cache
/// each combination instead of fetching for every keystroke.
@immutable
class DplCarryCandidatesKey {
  final int machineId;
  final DateTime? forDate;

  const DplCarryCandidatesKey({
    required this.machineId,
    this.forDate,
  });

  @override
  bool operator ==(Object other) =>
      other is DplCarryCandidatesKey &&
      other.machineId == machineId &&
      _ymd(other.forDate) == _ymd(forDate);

  @override
  int get hashCode => Object.hash(machineId, _ymd(forDate));

  static String _ymd(DateTime? d) {
    if (d == null) return '';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}

/// Cross-plan carry-forward candidates for a given machine + date.
final dplCarryCandidatesProvider = FutureProvider.autoDispose
    .family<DplApiResponse<List<DplCarryCandidate>>, DplCarryCandidatesKey>(
  (ref, key) async {
    return ref.read(dplApiServiceProvider).getCarryForwardCandidates(
          machineId: key.machineId,
          forDate: key.forDate,
        );
  },
);
