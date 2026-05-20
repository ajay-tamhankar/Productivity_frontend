import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/dpl_production_plan_item.dart';
import 'status_badge.dart';

class DplPlanItemTile extends StatelessWidget {
  final DplProductionPlanItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showActual;

  const DplPlanItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.showActual = true,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2EAF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF3FB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${item.planNo}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.partNumber.isEmpty
                              ? (item.partName.isEmpty
                                  ? 'Part #${item.partId}'
                                  : item.partName)
                              : item.partNumber,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                        if (item.partDescription.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              item.partDescription,
                              style: const TextStyle(
                                color: Color(0xFF5D6A7A),
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  DplStatusBadge(status: item.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _stat('Plan', fmt.format(item.planQty)),
                  const SizedBox(width: 12),
                  if (showActual) _stat('Actual', fmt.format(item.actualQty)),
                  const Spacer(),
                  Text(
                    '${(item.completionPct * 100).round()}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5D6A7A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            color: Color(0xFF5D6A7A),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
