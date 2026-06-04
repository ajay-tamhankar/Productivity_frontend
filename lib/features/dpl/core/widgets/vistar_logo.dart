import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../design/dpl_theme.dart';

/// Vistar brand mark + wordmark.
///
/// Pass [showWordmark]=true for the full logo (login hero), false for
/// the small mark used as the leading element on the app bar.
///
/// Falls back to a typographic placeholder when the asset can't be
/// found so screens render cleanly during onboarding of new variants.
class VistarLogo extends StatelessWidget {
  final double height;
  final bool showWordmark;
  final Color? fallbackColor;

  const VistarLogo({
    super.key,
    this.height = 28,
    this.showWordmark = false,
    this.fallbackColor,
  });

  // Single brand image used for both the wordmark and the small mark.
  // The PNG lives at the path below; the typographic fallbacks above
  // still kick in if the file is ever missing during onboarding.
  static const _logoAsset = 'assets/images/vistar_logo.png';

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _logoAsset,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() {
    if (showWordmark) {
      return _WordmarkFallback(
        height: height,
        color: fallbackColor ?? DplColors.primary,
      );
    }
    return _MarkFallback(
      size: height,
      color: fallbackColor ?? DplColors.primary,
    );
  }
}

class _MarkFallback extends StatelessWidget {
  final double size;
  final Color color;
  const _MarkFallback({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: DplColors.brandGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        'V',
        style: TextStyle(
          color: DplColors.textInverse,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.55,
          height: 1,
        ),
      ),
    );
  }
}

class _WordmarkFallback extends StatelessWidget {
  final double height;
  final Color color;
  const _WordmarkFallback({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MarkFallback(size: height, color: color),
          SizedBox(width: height * 0.25),
          Text(
            'Vistar',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: height * 0.7,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Preloads the Vistar logo so it never flashes on first render.
/// Call from `main()` after the binding is ready.
Future<void> precacheVistarLogos(BuildContext context) async {
  if (kIsWeb) return; // precache is no-op on web
  try {
    await precacheImage(
      const AssetImage(VistarLogo._logoAsset),
      context,
    );
  } catch (_) {
    // Asset missing during onboarding — fallbacks handle render.
  }
}
