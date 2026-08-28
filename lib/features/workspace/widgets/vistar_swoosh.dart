import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The Vistar "S" swoosh, drawn as vector layers rather than loaded from
/// the raster logo.
///
/// The shipped `vistar_logo.png` is the full *Vistar Pulse* wordmark, and
/// the launcher needs the bare mark at wildly different opacities — a 5%
/// page watermark, a card-corner accent, a breathing loader. Painting it
/// keeps every one of those crisp, tint-able and free of a background
/// plate, which a bitmap could not give us.
///
/// Construction: one spine curve, stroked eight times with shrinking
/// widths and progressive offsets along the ribbon normal, so the bands
/// stack from magenta on the outer edge down to cream in the core —
/// matching the printed mark.
class VistarSwoosh extends StatelessWidget {
  final double size;
  final double opacity;

  /// Paint every band in this single color instead of the ribbon. Used
  /// where the swoosh has to sit quietly behind content.
  final Color? tint;

  const VistarSwoosh({
    super.key,
    required this.size,
    this.opacity = 1.0,
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _VistarSwooshPainter(tint: tint)),
      ),
    );
  }
}

class _Band {
  final Color color;
  final double width;

  /// Distance the band's centre is pushed along the ribbon normal, so the
  /// outer edges of every band line up instead of nesting concentrically.
  final double offset;

  const _Band(this.color, this.width, this.offset);
}

class _VistarSwooshPainter extends CustomPainter {
  final Color? tint;

  const _VistarSwooshPainter({this.tint});

  // Outer edge → core. Widths and offsets are fractions of the box.
  static const List<_Band> _bands = <_Band>[
    _Band(Color(0xFFD24BD2), 0.150, 0.000),
    _Band(Color(0xFF7A1FB0), 0.120, 0.015),
    _Band(Color(0xFFC8102E), 0.098, 0.026),
    _Band(Color(0xFFF0480C), 0.078, 0.036),
    _Band(Color(0xFFF06000), 0.062, 0.044),
    _Band(Color(0xFFF0C000), 0.048, 0.051),
    _Band(Color(0xFFF7EE9A), 0.034, 0.058),
    _Band(Color(0xFFFFF6CC), 0.020, 0.065),
  ];

  /// Unit normal of the ribbon, pointing from the outer edge toward the
  /// core (down-right, perpendicular to the overall upper-right →
  /// lower-left flow).
  static final double _n = 1 / math.sqrt2;

  /// Half-thickness of the whole band stack, as a fraction of the box.
  /// Equals `_bands.first.width / 2` — the stack is symmetric about the
  /// spine — with a hair of slack so the clip never bites into the ink.
  static const double _halfStack = 0.078;

  /// Fraction of the curve each tip tapers over.
  static const double _tipRun = 0.30;

  @override
  void paint(Canvas canvas, Size size) {
    final box = math.min(size.width, size.height);
    // Inset so the widest stroke stays inside the painted box.
    final pad = box * 0.10;
    final span = box - pad * 2;

    Offset p(double x, double y) => Offset(pad + x * span, pad + y * span);

    final spine = Path()
      ..moveTo(p(1.00, 0.10).dx, p(1.00, 0.10).dy)
      ..cubicTo(
        p(0.72, 0.14).dx,
        p(0.72, 0.14).dy,
        p(0.40, 0.14).dx,
        p(0.40, 0.14).dy,
        p(0.36, 0.34).dx,
        p(0.36, 0.34).dy,
      )
      ..cubicTo(
        p(0.32, 0.53).dx,
        p(0.32, 0.53).dy,
        p(0.68, 0.48).dx,
        p(0.68, 0.48).dy,
        p(0.66, 0.66).dx,
        p(0.66, 0.66).dy,
      )
      ..cubicTo(
        p(0.64, 0.86).dx,
        p(0.64, 0.86).dy,
        p(0.30, 0.86).dx,
        p(0.30, 0.86).dy,
        p(0.00, 0.90).dx,
        p(0.00, 0.90).dy,
      );

    // The bands are uniform-width strokes; clipping them to a tapered
    // envelope is what pulls both ends out to the needle tips the
    // printed mark has.
    canvas.save();
    canvas.clipPath(_taperEnvelope(spine, _halfStack * span), doAntiAlias: true);

    for (final band in _bands) {
      final shift = band.offset * span * _n;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = band.width * span
        ..strokeCap = StrokeCap.butt
        ..strokeJoin = StrokeJoin.round
        ..color = tint ?? band.color
        ..isAntiAlias = true;
      canvas.drawPath(spine.shift(Offset(shift, shift)), paint);
    }

    canvas.restore();
  }

  /// Outline of the ribbon: the spine walked at ±`maxHalfWidth`, with the
  /// width easing to zero over [_tipRun] at each end.
  static Path _taperEnvelope(Path spine, double maxHalfWidth) {
    final metric = spine.computeMetrics().first;
    final length = metric.length;
    const steps = 220;

    final upper = <Offset>[];
    final lower = <Offset>[];

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final tangent = metric.getTangentForOffset(t * length);
      if (tangent == null) continue;
      final v = tangent.vector; // already unit length
      final normal = Offset(-v.dy, v.dx);
      final halfWidth = maxHalfWidth * _taper(t);
      upper.add(tangent.position + normal * halfWidth);
      lower.add(tangent.position - normal * halfWidth);
    }

    final path = Path()..moveTo(upper.first.dx, upper.first.dy);
    for (final o in upper.skip(1)) {
      path.lineTo(o.dx, o.dy);
    }
    for (final o in lower.reversed) {
      path.lineTo(o.dx, o.dy);
    }
    return path..close();
  }

  /// 0 at both tips, 1 across the body — raised to a power below 1 so the
  /// tips stay slender for longer instead of flaring linearly.
  static double _taper(double t) {
    final ramp = math.min(math.min(t, 1 - t) / _tipRun, 1.0);
    return math.pow(ramp, 0.5).toDouble();
  }

  @override
  bool shouldRepaint(covariant _VistarSwooshPainter oldDelegate) =>
      oldDelegate.tint != tint;
}

/// The splash / route-change loader from the Vistar design system: the
/// mark breathing between 0.92× and 1.04× inside two counter-spinning
/// rings.
class VistarBreathingMark extends StatefulWidget {
  final double size;
  final bool showRings;

  const VistarBreathingMark({super.key, this.size = 96, this.showRings = true});

  @override
  State<VistarBreathingMark> createState() => _VistarBreathingMarkState();
}

class _VistarBreathingMarkState extends State<VistarBreathingMark>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _spin;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _breathe.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringBox = widget.size * 2.05;

    return SizedBox(
      width: widget.showRings ? ringBox : widget.size,
      height: widget.showRings ? ringBox : widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.showRings) ...[
            _ring(
              diameter: ringBox,
              controller: _spin,
              reverse: false,
              top: const Color(0xA6E0218A),
              side: const Color(0x66F06000),
            ),
            _ring(
              diameter: ringBox - 44,
              controller: _spin,
              reverse: true,
              top: const Color(0xA69B30C9),
              side: const Color(0x73F0C000),
            ),
          ],
          AnimatedBuilder(
            animation: _breathe,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_breathe.value);
              return Transform.translate(
                offset: Offset(0, 2 - 4 * t),
                child: Transform.scale(scale: 0.92 + 0.12 * t, child: child),
              );
            },
            child: VistarSwoosh(size: widget.size),
          ),
        ],
      ),
    );
  }

  Widget _ring({
    required double diameter,
    required AnimationController controller,
    required bool reverse,
    required Color top,
    required Color side,
  }) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) => Transform.rotate(
        angle:
            controller.value *
            2 *
            math.pi *
            (reverse ? -1 : 1) *
            (reverse ? 0.73 : 1),
        child: child,
      ),
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: CustomPaint(painter: _ArcRingPainter(top: top, side: side)),
      ),
    );
  }
}

/// Two quarter-arcs of a circle — the design system's orbit ring. Painted
/// rather than built from a [Border] because Flutter only allows uniform
/// borders on circular decorations.
class _ArcRingPainter extends CustomPainter {
  final Color top;
  final Color side;

  const _ArcRingPainter({required this.top, required this.side});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.75);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    canvas.drawArc(rect, -3 * math.pi / 4, math.pi / 2, false, paint..color = top);
    canvas.drawArc(rect, -math.pi / 4, math.pi / 2, false, paint..color = side);
  }

  @override
  bool shouldRepaint(covariant _ArcRingPainter oldDelegate) =>
      oldDelegate.top != top || oldDelegate.side != side;
}
