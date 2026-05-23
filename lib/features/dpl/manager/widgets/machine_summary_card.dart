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
    final isPhone = MediaQuery.of(context).size.width < 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: EdgeInsets.all(isPhone ? 11 : 14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(isPhone ? 12 : 16),
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
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isPhone ? 14 : 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (summary.shiftLabel.isNotEmpty) ...[
                    _ShiftChip(label: summary.shiftLabel, isPhone: isPhone),
                    SizedBox(width: isPhone ? 6 : 8),
                  ],
                  DplStatusBadge(status: summary.status),
                ],
              ),
              SizedBox(height: isPhone ? 6 : 8),
              Row(
                children: [
                  Expanded(
                    child: _kv(
                      label: 'Plan Qty',
                      value: fmt.format(summary.planQty),
                      isPhone: isPhone,
                    ),
                  ),
                  Expanded(
                    child: _kv(
                      label: 'Actual',
                      value: fmt.format(summary.actualQty),
                      isPhone: isPhone,
                    ),
                  ),
                  Expanded(
                    child: _kv(
                      label: 'Completion',
                      value: '$pct%',
                      isPhone: isPhone,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isPhone ? 6 : 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: summary.completionPct.clamp(0, 1),
                  minHeight: isPhone ? 5 : 6,
                  backgroundColor: const Color(0xFFEEF1F5),
                ),
              ),
              SizedBox(height: isPhone ? 6 : 8),
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: isPhone ? 14 : 16,
                    color: const Color(0xFF5D6A7A),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      summary.supervisorName.isEmpty
                          ? 'No supervisor assigned'
                          : summary.supervisorName,
                      style: TextStyle(
                        color: const Color(0xFF5D6A7A),
                        fontWeight: FontWeight.w600,
                        fontSize: isPhone ? 12 : 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: isPhone ? 12 : 14,
                    color: const Color(0xFF5D6A7A),
                  ),
                ],
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
    required bool isPhone,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isPhone ? 10 : 11,
            color: const Color(0xFF5D6A7A),
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: isPhone ? 14 : 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

/// Compact "Shift A" pill rendered on the machine card title row.
class _ShiftChip extends StatelessWidget {
  final String label;
  final bool isPhone;

  const _ShiftChip({required this.label, required this.isPhone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 6 : 8,
        vertical: isPhone ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: const Color(0xFF3730A3),
          fontWeight: FontWeight.w700,
          fontSize: isPhone ? 10 : 11,
          height: 1.0,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
