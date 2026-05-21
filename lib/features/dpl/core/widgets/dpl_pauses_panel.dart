import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dpl_item_pause.dart';

/// Reusable list of pause records, used by both manager and supervisor
/// Plan Detail screens. Caller is responsible for fetching the list
/// (different endpoints per role) and passing the loading / error /
/// data state in via the named constructors.
class DplPausesPanel extends StatelessWidget {
  final List<DplItemPause> pauses;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  const DplPausesPanel({
    super.key,
    required this.pauses,
    required this.onRetry,
    this.loading = false,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return _ErrorBox(message: error!, onRetry: onRetry);
    }
    if (pauses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'No pauses recorded for this plan yet.',
          style: TextStyle(
            color: Color(0xFF5D6A7A),
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final p in pauses) _PauseTile(pause: p),
      ],
    );
  }
}

class _PauseTile extends StatelessWidget {
  final DplItemPause pause;
  const _PauseTile({required this.pause});

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('d MMM, HH:mm');
    final paused = timeFmt.format(pause.pausedAt.toLocal());
    final resumed = pause.resumedAt == null
        ? null
        : timeFmt.format(pause.resumedAt!.toLocal());

    final isActive = pause.isActive;
    final accent =
        isActive ? const Color(0xFFB45309) : const Color(0xFF1D4ED8);
    final headlineLeft = pause.planItemNo != null
        ? 'Plan #${pause.planItemNo}'
        : 'Item #${pause.planItemId}';
    final reasonName = pause.reasonName ?? '';
    final hasReason = reasonName.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headlineLeft,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: isActive
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isActive
                      ? 'Active'
                      : '${pause.durationMinutes ?? 0} min',
                  style: TextStyle(
                    color: isActive
                        ? const Color(0xFF92400E)
                        : const Color(0xFF075985),
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 13),
            child: Text(
              resumed == null
                  ? 'Paused $paused'
                  : 'Paused $paused → Resumed $resumed',
              style: const TextStyle(
                color: Color(0xFF5D6A7A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (hasReason) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 13),
              child: Row(
                children: [
                  const Icon(Icons.flag_outlined,
                      size: 12, color: Color(0xFF5D6A7A)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      reasonName,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (pause.reasonText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 13),
              child: Text(
                pause.reasonText,
                style: const TextStyle(
                  color: Color(0xFF111827),
                  fontSize: 12,
                ),
              ),
            ),
          ],
          if ((pause.pausedByName ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 13),
              child: Text(
                'By ${pause.pausedByName}'
                '${pause.shiftId != null ? '  •  Shift ${pause.shiftId}' : ''}',
                style: const TextStyle(
                  color: Color(0xFF9CA3AF),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFFB4AA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF8F1D18),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
