import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../models/dpl_identity.dart';

/// Latest result of `GET /supervisor/identity/status`.
///
/// The IdentityGate widget watches this. After a successful selfie
/// upload, call `ref.invalidate(dplIdentityStatusProvider)` to force a
/// fresh check (which should now return `verified: true`).
final dplIdentityStatusProvider = FutureProvider.autoDispose<
    DplApiResponse<DplIdentityStatus>>((ref) async {
  return ref.watch(dplApiServiceProvider).getIdentityStatus();
});
