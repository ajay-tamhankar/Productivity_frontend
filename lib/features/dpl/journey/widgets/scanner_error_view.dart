import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Error surface for every DPL camera scanner.
///
/// `mobile_scanner`'s built-in error widget renders one flat line —
/// "An unexpected error occurred." — for its entire `genericError`
/// bucket, and drops the underlying platform message on the floor. On
/// web that bucket is everything `getUserMedia` can throw except
/// `NotFoundError` and `NotAllowedError`, which in practice means the
/// two most common real causes are indistinguishable from each other and
/// from a genuine bug:
///
///   * **NotReadableError** — another app or browser tab already holds
///     the camera. Very common on Windows (Teams, Zoom, a second tab of
///     this same app left open on a scanner screen).
///   * **OverconstrainedError / AbortError** — the device can't satisfy
///     the requested camera, or the OS aborted the capture.
///
/// A guard on a gate cannot act on "an unexpected error occurred", and
/// neither can whoever they call. So this widget names the likely cause,
/// says what to do about it, and still shows the raw platform string for
/// whoever ends up debugging it.
class ScannerErrorView extends StatelessWidget {
  final MobileScannerException error;

  /// Restarts the camera. Wire to `controller.start()`.
  final Future<void> Function()? onRetry;

  const ScannerErrorView({super.key, required this.error, this.onRetry});

  /// Raw platform message, e.g. the DOMException string on web. This is
  /// the only place the actual cause is visible, so it is always shown
  /// rather than hidden behind a "details" toggle.
  String? get _rawMessage {
    final m = error.errorDetails?.message?.trim();
    if (m == null || m.isEmpty) return null;
    return m;
  }

  bool get _cameraBusy {
    final m = _rawMessage ?? '';
    return m.contains('NotReadableError') ||
        m.contains('TrackStartError') ||
        m.contains('Could not start video source');
  }

  _Copy get _copy {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return const _Copy(
          icon: Icons.no_photography_outlined,
          title: 'Camera permission blocked',
          body: 'Allow camera access for this site, then tap Retry. In the '
              'browser this is the camera icon in the address bar; on the '
              'phone it is Settings → Apps → Vistar Pulse → Permissions.',
        );
      case MobileScannerErrorCode.unsupported:
        // NotFoundError. The browser enumerated zero video inputs — this is
        // not a permission problem, the camera is absent as far as the OS is
        // concerned. On laptops that is usually a privacy shutter or an
        // Fn-key kill switch, which physically de-enumerates the camera
        // (Windows then reports it as a phantom device, Code 45). Flipping
        // it back makes the camera reappear and Retry works without a reload.
        return const _Copy(
          icon: Icons.videocam_off_outlined,
          title: 'No camera detected',
          body: 'The device has no camera switched on. Check the privacy '
              'shutter or the camera Fn-key on the keyboard, then tap Retry. '
              'Otherwise use the Vistar Pulse app on the handheld.',
        );
      case MobileScannerErrorCode.controllerAlreadyInitialized:
        return const _Copy(
          icon: Icons.sync_problem_rounded,
          title: 'Scanner is already running',
          body: 'Another scanner screen is still open in this session. Go '
              'back, close it, and open this one again.',
        );
      // genericError plus anything a future package version adds — the
      // raw platform message below is what actually identifies these.
      default:
        if (_cameraBusy) {
          return const _Copy(
            icon: Icons.videocam_off_outlined,
            title: 'Camera is already in use',
            body: 'Another app or browser tab is holding the camera. Close '
                'Teams / Zoom / any other Vistar Pulse tab that has a scanner '
                'open, then tap Retry.',
          );
        }
        return _Copy(
          icon: Icons.error_outline_rounded,
          title: 'Camera could not start',
          body: kIsWeb
              ? 'The browser refused to open the camera. The usual cause is '
                  'another app or tab already using it — close those and tap '
                  'Retry. If it keeps failing, use the Vistar Pulse app.'
              : 'The camera could not be started. Tap Retry, or restart the '
                  'app if it keeps failing.',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = _copy;
    final raw = _rawMessage;

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(copy.icon, size: 44, color: Colors.white70),
              const SizedBox(height: 14),
              Text(
                copy.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                copy.body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  onPressed: () => onRetry!(),
                ),
              ],
              if (raw != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    raw,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10.5,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Copy {
  final IconData icon;
  final String title;
  final String body;
  const _Copy({required this.icon, required this.title, required this.body});
}
