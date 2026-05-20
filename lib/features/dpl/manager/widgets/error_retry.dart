import 'package:flutter/material.dart';

class DplErrorRetry extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const DplErrorRetry({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFB3261E),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8F1D18),
                fontWeight: FontWeight.w600,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Snackbar helpers used across DPL screens. Standardises green/red.
class DplSnack {
  const DplSnack._();

  static void success(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
      ));
  }

  static void error(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
  }

  static void info(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ));
  }
}
