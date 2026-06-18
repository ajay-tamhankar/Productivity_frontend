import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_part_field.dart';

/// Listing for the given field kind. Always called with `with_null=true`
/// because the edit screen wants to show every part — both already-set
/// and not-yet-configured — so the manager can fill in the gaps.
final dplPartFieldPageProvider = FutureProvider.autoDispose
    .family<DplApiResponse<DplPartFieldPage>, DplPartFieldKind>(
  (ref, kind) async {
    return ref
        .watch(dplApiServiceProvider)
        .listPartField(kind, withNull: true);
  },
);
