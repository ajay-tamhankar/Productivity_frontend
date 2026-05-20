import 'package:flutter/material.dart';

import '../../core/dpl_constants.dart';
import '../design/dpl_theme.dart';

/// Pill-shaped status indicator. Solid dot + label, background tinted
/// at 10% opacity of the foreground color.
///
/// Phase-2 rebuild of the old `DplStatusBadge` — same public name, new
/// visuals. The old widget remains until callers migrate.
class DplStatusPill extends StatelessWidget {
  final String status;

  const DplStatusPill({super.key, required this.status});

  Color _color() {
    switch (status) {
      case DplPlanStatus.draft:
        return DplColors.statusDraft;
      case DplPlanStatus.published:
        return DplColors.statusPublished;
      case DplPlanStatus.inProgress:
        return DplColors.statusInProgress;
      case DplPlanStatus.completed:
        return DplColors.statusCompleted;
      case DplPlanStatus.locked:
        return DplColors.statusLocked;
      default:
        return DplColors.statusDraft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(DplRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            DplPlanStatus.label(status),
            style: DplText.bodySm().copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
