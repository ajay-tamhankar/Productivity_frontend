import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dpl_dashboard_summary.dart';
import 'status_badge.dart';

class DplMachineSummaryCard extends StatelessWidget {
  final DplMachineSummary summary;
  final VoidCallback? onTap;

  const DplMachineSummaryCard({
    super.key,
    required this.summary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final pct = (summary.completionPct * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EAF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.machineName.isEmpty
                          ? 'Machine #${summary.machineId}'
                          : summary.machineName,
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  DplStatusBadge(status: summary.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _kv(
                      label: 'Plan Qty',
                      value: fmt.format(summary.planQty),
                    ),
                  ),
                  Expanded(
                    child: _kv(
                      label: 'Actual',
                      value: fmt.format(summary.actualQty),
                    ),
                  ),
                  Expanded(
                    child: _kv(
                      label: 'Completion',
                      value: '$pct%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: summary.completionPct.clamp(0, 1),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEEF1F5),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Color(0xFF5D6A7A),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      summary.supervisorName.isEmpty
                          ? 'No supervisor assigned'
                          : summary.supervisorName,
                      style: const TextStyle(
                        color: Color(0xFF5D6A7A),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: Color(0xFF5D6A7A),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv({required String label, required String value}) {
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
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
