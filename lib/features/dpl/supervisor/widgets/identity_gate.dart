import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../manager/widgets/error_retry.dart';
import '../../models/dpl_identity.dart';
import '../providers/dpl_identity_provider.dart';
import 'selfie_modal.dart';

/// Per-tap safety net for Supervisor flows.
///
/// The primary gate is `ShiftIdentityGuard` mounted at the supervisor
/// shell — it locks the whole app until a selfie is captured for the
/// current shift. This per-tap variant only fires if something slipped
/// past the shell-level guard (e.g. a deep link). It uses the same
/// server-owned `verified_for_current_shift` flag, so a verified shift
/// never re-prompts.
class IdentityGate {
  const IdentityGate._();

  static Future<void> run(
    BuildContext context,
    WidgetRef ref, {
    required String gateContext,
    required VoidCallback onProceed,
    int? planId,
    int? planItemId,
  }) async {
    // Read latest status — provider may already have it cached.
    final asyncStatus = ref.read(dplIdentityStatusProvider);
    DplIdentityStatus? status = asyncStatus.asData?.value.data;

    // If we don't have a cached value yet, force a refresh.
    if (status == null) {
      ref.invalidate(dplIdentityStatusProvider);
      try {
        final res = await ref.read(dplIdentityStatusProvider.future);
        if (res.isOk) status = res.data;
      } catch (_) {
        // ignore — handled below
      }
    }

    if (!context.mounted) return;

    // Fail-open: if status can't be fetched, let the user proceed but
    // tell them verification will be required when the backend recovers.
    if (status == null) {
      DplSnack.info(
        context,
        'Identity check unavailable right now — please verify when prompted next.',
      );
      onProceed();
      return;
    }

    if (!status.required || status.verifiedForCurrentShift) {
      onProceed();
      return;
    }

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (_) => SelfieModal(
        context: gateContext,
        planId: planId,
        planItemId: planItemId,
      ),
    );

    if (!context.mounted) return;
    ref.invalidate(dplIdentityStatusProvider);
    if (ok == true) onProceed();
  }
}
