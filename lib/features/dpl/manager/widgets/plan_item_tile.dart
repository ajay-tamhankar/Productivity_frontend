import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/shift_chip.dart';
import '../../models/dpl_production_plan_item.dart';
import '../../supervisor/widgets/live_timer_text.dart';
import 'status_badge.dart';
import 'trolley_photo_thumbnail.dart';

enum _ItemMenuAction { edit, changeStatus, carryForward, delete }

class DplPlanItemTile extends StatelessWidget {
  final DplProductionPlanItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Manager-only callback: opens the Edit Item dialog (where shift,
  /// qty, part, etc. can be changed). When null, the overflow menu
  /// hides the "Edit" row. Pair this with `onTap` for the same dialog
  /// so both gestures lead to the same place.
  final VoidCallback? onEdit;

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
    this.onEdit,
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
                  if (onEdit != null ||
                      onChangeStatus != null ||
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
                          case _ItemMenuAction.edit:
                            onEdit?.call();
                            break;
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
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: _ItemMenuAction.edit,
                            child: ListTile(
                              dense: true,
                              leading: Icon(Icons.edit_outlined),
                              title: Text('Edit item'),
                              subtitle: Text(
                                'Change shift, qty, part, etc.',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ),
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
                                'Splits leftover (${item.planQty - item.actualQty}) '
                                'into a new shift; this item stays.',
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
              // Live status strip for non-pending items so the
              // manager can glance at how an item is doing without
              // drilling into the plan or pinging the supervisor.
              if (item.status != 'pending') ...[
                const SizedBox(height: 8),
                _LiveStatusStrip(item: item),
              ],
              // Accumulated downtime chip — stays visible after a
              // downtime is resumed (and after the item completes)
              // so the manager can see total minutes lost without
              // having to wait for the item to stop.
              if (item.status != 'pending' &&
                  item.totalPausedMinutes > 0 &&
                  item.pausedAt == null) ...[
                const SizedBox(height: 6),
                _DowntimeAccumulatedChip(minutes: item.totalPausedMinutes),
              ],
              // Trolley photo captured at STOP time — supervisors
              // are required to snap it before completing an item,
              // so for completed items there should always be one.
              // Tap to open full-screen.
              if (item.status == 'completed' &&
                  (item.stopTrolleyPhotoUrl ?? '').isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    TrolleyPhotoThumbnail(
                      photoUrl: item.stopTrolleyPhotoUrl,
                      heroTag: 'trolley-${item.id}',
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Trolley photo captured at stop. Tap to view.',
                        style: TextStyle(
                          color: Color(0xFF5D6A7A),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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

/// Single-line live state shown under the Plan/Actual row on
/// non-pending items. Branches:
///   * `in_progress` + `pausedAt != null` → "Paused since 10:30"
///   * `in_progress` + running             → "Started 09:15 - Running [live timer]"
///   * `completed`                         → "Completed at 11:42 - Took 2h 27m"
///   * Anything else (e.g. unknown status) → no strip
class _LiveStatusStrip extends StatelessWidget {
  final DplProductionPlanItem item;
  const _LiveStatusStrip({required this.item});

  static String _hm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _duration(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final isPaused = item.pausedAt != null;
    final isCompleted = item.status == 'completed';

    if (isCompleted) {
      final end = item.endTime?.toLocal();
      final start = item.startTime?.toLocal();
      final dur = (start != null && end != null)
          ? end.difference(start) -
              Duration(minutes: item.totalPausedMinutes)
          : null;
      return _strip(
        icon: Icons.check_circle_outline,
        color: const Color(0xFF15803D),
        bg: const Color(0xFFE6F4EA),
        text: end == null
            ? 'Completed'
            : (dur == null
                ? 'Completed at ${_hm(end)}'
                : 'Completed at ${_hm(end)}  -  Took ${_duration(dur)}'),
      );
    }

    if (isPaused) {
      return _PausedStripWithLiveTimer(pausedAt: item.pausedAt!);
    }

    // In progress, running.
    final start = item.startTime;
    if (start == null) {
      return _strip(
        icon: Icons.play_circle_outline,
        color: const Color(0xFF1D4ED8),
        bg: const Color(0xFFDBEAFE),
        text: 'In progress',
      );
    }
    return _StripWithLiveTimer(start: start);
  }

  static Widget _strip({
    required IconData icon,
    required Color color,
    required Color bg,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small red chip showing total downtime accumulated on an item.
/// Stays visible after a downtime is resumed (where the live
/// paused-since strip disappears) so the manager can see how much
/// time was lost without waiting for the item to be stopped.
class _DowntimeAccumulatedChip extends StatelessWidget {
  final int minutes;
  const _DowntimeAccumulatedChip({required this.minutes});

  String _format(int minutes) {
    if (minutes <= 0) return '0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFB3261E);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.timer_off_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Downtime so far: ${_format(minutes)}',
              style: const TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PausedStripWithLiveTimer extends StatelessWidget {
  final DateTime pausedAt;
  const _PausedStripWithLiveTimer({required this.pausedAt});

  @override
  Widget build(BuildContext context) {
    final localPaused = pausedAt.toLocal();
    final hm = '${localPaused.hour.toString().padLeft(2, '0')}:'
        '${localPaused.minute.toString().padLeft(2, '0')}';
    const color = Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.pause_circle_outline, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            'Paused since $hm  -  Paused for ',
            style: const TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          LiveTimerText(
            startTime: pausedAt,
            style: const TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StripWithLiveTimer extends StatelessWidget {
  final DateTime start;
  const _StripWithLiveTimer({required this.start});

  @override
  Widget build(BuildContext context) {
    final localStart = start.toLocal();
    final hm = '${localStart.hour.toString().padLeft(2, '0')}:'
        '${localStart.minute.toString().padLeft(2, '0')}';
    const color = Color(0xFF15803D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F4EA),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            'Started $hm  -  Running ',
            style: const TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
          LiveTimerText(
            startTime: start,
            style: const TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
