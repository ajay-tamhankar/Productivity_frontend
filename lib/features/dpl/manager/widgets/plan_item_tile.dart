import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/shift_chip.dart';
import '../../models/dpl_production_plan_item.dart';
import 'status_badge.dart';

enum _ItemMenuAction { changeStatus, carryForward, delete }

class DplPlanItemTile extends StatelessWidget {
  final DplProductionPlanItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Manager-only callback: opens the per-item status override sheet.
  /// When null, the overflow menu doesn't show a "Change status" row.
  final VoidCallback? onChangeStatus;

  /// Manager-only callback: opens the carry-forward-to-next-shift sheet.
  /// When null, the overflow menu doesn't show the row.
  final VoidCallback? onCarryForward;

  /// Manager-only callback for the overflow menu. When null, the menu
  /// hides the "Delete" row (the long-press path stays untouched).
  final VoidCallback? onDelete;

  final bool showActual;

  const DplPlanItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onLongPress,
    this.onChangeStatus,
    this.onCarryForward,
    this.onDelete,
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      DplStatusBadge(status: item.status),
                      if (item.shiftDisplayLabel != null) ...[
                        const SizedBox(height: 4),
                        DplShiftChip(label: item.shiftDisplayLabel!),
                      ],
                    ],
                  ),
                  if (onChangeStatus != null ||
                      onCarryForward != null ||
                      onDelete != null)
                    PopupMenuButton<_ItemMenuAction>(
                      tooltip: 'More',
                      icon: const Icon(
                        Icons.more_vert,
                        color: Color(0xFF5D6A7A),
                      ),
                      onSelected: (a) {
                        switch (a) {
                          case _ItemMenuAction.changeStatus:
                            onChangeStatus?.call();
                            break;
                          case _ItemMenuAction.carryForward:
                            onCarryForward?.call();
                            break;
                          case _ItemMenuAction.delete:
                            onDelete?.call();
                            break;
                        }
                      },
                      itemBuilder: (_) => [
                        if (onChangeStatus != null)
                          const PopupMenuItem(
                            value: _ItemMenuAction.changeStatus,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.swap_horiz_outlined),
                              title: Text('Change status'),
                            ),
                          ),
                        // "Carry to next shift" only makes sense when
                        // there's leftover qty to push forward.
                        if (onCarryForward != null &&
                            item.planQty - item.actualQty > 0)
                          PopupMenuItem(
                            value: _ItemMenuAction.carryForward,
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.skip_next_outlined),
                              title: const Text('Carry to next shift'),
                              subtitle: Text(
                                'Leftover: ${item.planQty - item.actualQty}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: _ItemMenuAction.delete,
                            child: ListTile(
                              dense: true,
                              leading: Icon(
                                Icons.delete_outline,
                                color: Color(0xFFB3261E),
                              ),
                              title: Text(
                                'Delete',
                                style: TextStyle(color: Color(0xFFB3261E)),
                              ),
                            ),
                          ),
                      ],
                    ),
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
