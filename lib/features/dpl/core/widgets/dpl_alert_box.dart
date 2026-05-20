import 'package:flutter/material.dart';

import '../design/dpl_theme.dart';

enum DplAlertVariant { info, warning, error, success }

/// Inline alert box — replaces ad-hoc colored boxes scattered across
/// the upload form, masters screens, and the supervisor execution
/// confirm dialog.
class DplAlertBox extends StatelessWidget {
  final DplAlertVariant variant;
  final String? title;

  /// Single line of message text. Mutually exclusive with [bullets].
  final String? message;

  /// Bullet list. Mutually exclusive with [message]; if both are
  /// provided, [message] renders above the bullets as a lead-in.
  final List<String> bullets;

  const DplAlertBox({
    super.key,
    this.variant = DplAlertVariant.info,
    this.title,
    this.message,
    this.bullets = const [],
  });

  _AlertSpec _spec() {
    switch (variant) {
      case DplAlertVariant.warning:
        return _AlertSpec(
          icon: Icons.warning_amber_rounded,
          fg: DplColors.warning,
          bg: DplColors.warningBg,
        );
      case DplAlertVariant.error:
        return _AlertSpec(
          icon: Icons.error_outline,
          fg: DplColors.error,
          bg: DplColors.errorBg,
        );
      case DplAlertVariant.success:
        return _AlertSpec(
          icon: Icons.check_circle_outline,
          fg: DplColors.success,
          bg: DplColors.successBg,
        );
      case DplAlertVariant.info:
        return _AlertSpec(
          icon: Icons.info_outline,
          fg: DplColors.info,
          bg: DplColors.infoBg,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final spec = _spec();
    final textStyle = DplText.bodySm().copyWith(color: spec.fg);
    return Container(
      padding: const EdgeInsets.all(DplSpacing.md),
      decoration: BoxDecoration(
        color: spec.bg,
        borderRadius: BorderRadius.circular(DplRadius.md),
        border: Border.all(color: spec.fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(spec.icon, color: spec.fg, size: 20),
          const SizedBox(width: DplSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      title!,
                      style: DplText.bodySm().copyWith(
                        color: spec.fg,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                if (message != null) Text(message!, style: textStyle),
                if (bullets.isNotEmpty) ...[
                  if (message != null) const SizedBox(height: 4),
                  for (final b in bullets)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('•  ', style: textStyle),
                          Expanded(child: Text(b, style: textStyle)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertSpec {
  final IconData icon;
  final Color fg;
  final Color bg;
  const _AlertSpec({required this.icon, required this.fg, required this.bg});
}
