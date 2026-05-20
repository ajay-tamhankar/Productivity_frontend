import 'package:flutter/material.dart';

import '../design/dpl_theme.dart';

enum DplEmptyVariant { noData, error, comingSoon }

/// Branded empty / error state. 80dp icon in a primary-tint circle,
/// title in h2, description in body-secondary, optional action.
class DplEmptyView extends StatelessWidget {
  final DplEmptyVariant variant;
  final String title;
  final String? message;
  final Widget? action;
  final IconData? icon;

  const DplEmptyView({
    super.key,
    this.variant = DplEmptyVariant.noData,
    required this.title,
    this.message,
    this.action,
    this.icon,
  });

  IconData _icon() {
    if (icon != null) return icon!;
    switch (variant) {
      case DplEmptyVariant.error:
        return Icons.error_outline;
      case DplEmptyVariant.comingSoon:
        return Icons.hourglass_empty;
      case DplEmptyVariant.noData:
        return Icons.inbox_outlined;
    }
  }

  Color _iconColor() {
    switch (variant) {
      case DplEmptyVariant.error:
        return DplColors.error;
      case DplEmptyVariant.comingSoon:
        return DplColors.warning;
      case DplEmptyVariant.noData:
        return DplColors.primary;
    }
  }

  Color _tint() {
    switch (variant) {
      case DplEmptyVariant.error:
        return DplColors.errorBg;
      case DplEmptyVariant.comingSoon:
        return DplColors.warningBg;
      case DplEmptyVariant.noData:
        return DplColors.primaryTint;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DplSpacing.xxl),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _tint(),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(_icon(), size: 36, color: _iconColor()),
            ),
            const SizedBox(height: DplSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: DplText.h2(),
            ),
            if (message != null) ...[
              const SizedBox(height: DplSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style:
                    DplText.body().copyWith(color: DplColors.textSecondary),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: DplSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
