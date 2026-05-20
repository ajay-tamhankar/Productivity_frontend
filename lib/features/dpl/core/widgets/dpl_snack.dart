import 'package:flutter/material.dart';

import '../design/dpl_theme.dart';

enum DplSnackVariant { success, error, warning, info }

/// Branded snackbar helpers. Auto-dismiss after 3s (4s for error),
/// floating, soft shadow, slide up from bottom. Tap to dismiss.
class DplSnacks {
  const DplSnacks._();

  static void success(BuildContext context, String message) =>
      _show(context, DplSnackVariant.success, message);

  static void error(BuildContext context, String message) =>
      _show(context, DplSnackVariant.error, message);

  static void warning(BuildContext context, String message) =>
      _show(context, DplSnackVariant.warning, message);

  static void info(BuildContext context, String message) =>
      _show(context, DplSnackVariant.info, message);

  static void _show(
    BuildContext context,
    DplSnackVariant variant,
    String message,
  ) {
    final messenger = ScaffoldMessenger.of(context);
    final spec = _specFor(variant);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          padding: EdgeInsets.zero,
          duration: variant == DplSnackVariant.error
              ? const Duration(seconds: 4)
              : const Duration(seconds: 3),
          content: GestureDetector(
            onTap: messenger.hideCurrentSnackBar,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: DplSpacing.md,
                vertical: DplSpacing.md,
              ),
              decoration: BoxDecoration(
                color: spec.bg,
                borderRadius: BorderRadius.circular(DplRadius.md),
                border: Border.all(
                  color: spec.fg.withValues(alpha: 0.2),
                ),
                boxShadow: DplShadows.card,
              ),
              child: Row(
                children: [
                  Icon(spec.icon, color: spec.fg, size: 20),
                  const SizedBox(width: DplSpacing.sm),
                  Expanded(
                    child: Text(
                      message,
                      style: DplText.bodySm()
                          .copyWith(color: spec.fg, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }

  static _SnackSpec _specFor(DplSnackVariant v) {
    switch (v) {
      case DplSnackVariant.success:
        return _SnackSpec(
          icon: Icons.check_circle_outline,
          fg: DplColors.success,
          bg: DplColors.successBg,
        );
      case DplSnackVariant.error:
        return _SnackSpec(
          icon: Icons.error_outline,
          fg: DplColors.error,
          bg: DplColors.errorBg,
        );
      case DplSnackVariant.warning:
        return _SnackSpec(
          icon: Icons.warning_amber_rounded,
          fg: DplColors.warning,
          bg: DplColors.warningBg,
        );
      case DplSnackVariant.info:
        return _SnackSpec(
          icon: Icons.info_outline,
          fg: DplColors.info,
          bg: DplColors.infoBg,
        );
    }
  }
}

class _SnackSpec {
  final IconData icon;
  final Color fg;
  final Color bg;
  const _SnackSpec({required this.icon, required this.fg, required this.bg});
}
