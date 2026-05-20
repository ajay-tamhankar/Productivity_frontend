import 'package:flutter/material.dart';

import '../../core/dpl_constants.dart';

/// Colour-coded pill for plan / item status.
class DplStatusBadge extends StatelessWidget {
  final String status;
  final EdgeInsets padding;
  final double fontSize;

  const DplStatusBadge({
    super.key,
    required this.status,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    this.fontSize = 11,
  });

  Color _bg() {
    switch (status) {
      case DplPlanStatus.draft:
        return const Color(0xFFEEF1F5);
      case DplPlanStatus.published:
        return const Color(0xFFE0EFFF);
      case DplPlanStatus.inProgress:
        return const Color(0xFFFEF3C7);
      case DplPlanStatus.completed:
        return const Color(0xFFD1FAE5);
      case DplPlanStatus.locked:
        return const Color(0xFFE5E7EB);
      case 'pending':
        return const Color(0xFFEEF1F5);
      default:
        return const Color(0xFFEEF1F5);
    }
  }

  Color _fg() {
    switch (status) {
      case DplPlanStatus.draft:
        return const Color(0xFF4B5563);
      case DplPlanStatus.published:
        return const Color(0xFF1D4ED8);
      case DplPlanStatus.inProgress:
        return const Color(0xFFB45309);
      case DplPlanStatus.completed:
        return const Color(0xFF047857);
      case DplPlanStatus.locked:
        return const Color(0xFF374151);
      case 'pending':
        return const Color(0xFF4B5563);
      default:
        return const Color(0xFF4B5563);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _bg(),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        DplPlanStatus.label(status),
        style: TextStyle(
          color: _fg(),
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
