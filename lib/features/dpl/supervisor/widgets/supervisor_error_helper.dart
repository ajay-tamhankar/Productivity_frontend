import 'package:flutter/material.dart';

import '../../core/dpl_api_response.dart';
import '../../manager/widgets/error_retry.dart';

/// Centralised mapping of business-rule error codes to user-facing UI.
///
/// Returns `true` if a code-specific dialog/snackbar was shown so the
/// caller knows not to also surface a generic error.
bool handleSupervisorError(
  BuildContext context,
  DplApiResponse response, {
  String fallback = 'Something went wrong.',
  VoidCallback? onGoToRunningItem,
}) {
  final code = response.code ?? '';
  final msg = response.error ?? fallback;

  switch (code) {
    case 'ITEM_ALREADY_RUNNING':
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Another item is running'),
          content: const Text(
            'Stop the currently-running item on this machine before '
            'starting a new one.',
          ),
          actions: [
            if (onGoToRunningItem != null)
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onGoToRunningItem();
                },
                child: const Text('Go to running item'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return true;

    case 'ACTIVE_DOWNTIME_EXISTS':
      DplSnack.info(
        context,
        'A downtime is already active on this machine.',
      );
      return true;

    case 'RESOLVE_DOWNTIME_FIRST':
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Resume from downtime first'),
          content: const Text(
            'You must resume from the active downtime before completing '
            'this item.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return true;

    case 'INCOMPLETE_ITEMS':
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Plan items still running'),
          content: const Text(
            'Complete or stop all running items before submitting the '
            'shift.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return true;

    case 'NOT_YOUR_PLAN':
      DplSnack.error(context, 'This plan is not assigned to you.');
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      return true;

    case 'FORBIDDEN_ROLE':
      // The Dio 401/403 interceptor handles auto-logout. Just signal.
      DplSnack.error(context, 'Your session expired. Please log in again.');
      return true;

    default:
      DplSnack.error(context, msg);
      return false;
  }
}
