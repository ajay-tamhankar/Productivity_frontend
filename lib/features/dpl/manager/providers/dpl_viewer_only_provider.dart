import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/auth_provider.dart';

/// `true` when the signed-in user is a DPL_CUSTOMER — i.e. they should
/// see the DPL Manager dashboard + plans tab but be blocked from every
/// mutating action (create / edit / delete / upload / start / stop).
///
/// Single source of truth for read-only gating in the DPL surface. Any
/// widget that exposes a write action should `ref.watch` this and short-
/// circuit when it returns true.
final dplViewerOnlyProvider = Provider<bool>((ref) {
  final user = ref.watch(authControllerProvider).asData?.value;
  if (user == null) return false;
  return AppConstants.isDplCustomerRole(user.role);
});
