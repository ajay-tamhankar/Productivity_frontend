import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../manager/widgets/status_badge.dart';
import '../../models/dpl_supervisor_today.dart';
import 'live_timer_text.dart';

/// Big, tappable machine card used on the Supervisor Dashboard.
/// Shows plan/actual/completion, supervisor status, and a sticky red
/// downtime sub-banner when a downtime is active.
class MachineTileLarge extends StatelessWidget {
  final SupervisorPlanSummary plan;
  final VoidCallback onTap;

  const MachineTileLarge({
    super.key,
    required this.plan,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final pct = (plan.completionPct * 100).round();
    final down = plan.activeDowntime;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2EAF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            plan.machineName.isEmpty
                                ? 'Machine #${plan.machineId}'
                                : plan.machineName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        DplStatusBadge(status: plan.status),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _kv(
                            label: 'Plan',
                            value: fmt.format(plan.totalPlanQty),
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                        Expanded(
                          child: _kv(
                            label: 'Actual',
                            value: fmt.format(plan.totalActualQty),
                            color: const Color(0xFF047857),
                          ),
                        ),
                        Expanded(
                          child: _kv(
                            label: 'Completion',
                            value: '$pct%',
                            color: const Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: plan.completionPct,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFEEF1F5),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${plan.itemsCompleted} done · '
                      '${plan.itemsInProgress} running · '
                      '${plan.itemsPending} pending',
                      style: const TextStyle(
                        color: Color(0xFF5D6A7A),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (down != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFB3261E),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(17),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'DOWNTIME: ${down.reasonName.isEmpty ? "Active" : down.reasonName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      LiveTimerText(
                        startTime: down.startTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv({
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF5D6A7A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
