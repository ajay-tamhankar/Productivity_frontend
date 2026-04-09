import 'package:flutter/material.dart';

class AppShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = widget.baseColor ??
        (isDark ? const Color(0xFF2A3442) : const Color(0xFFE3EBF7));
    final highlightColor = widget.highlightColor ??
        (isDark ? const Color(0xFF3A4656) : const Color(0xFFF6FAFF));

    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 - (2 * _controller.value), 0),
              end: Alignment(1.0 + (2 * _controller.value), 0),
              colors: <Color>[
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: const <double>[0.35, 0.5, 0.65],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadiusGeometry borderRadius;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF2A3442) : const Color(0xFFE3EBF7);

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
    );
  }
}

class ShimmerCenteredPlaceholder extends StatelessWidget {
  final double verticalPadding;
  final double titleWidth;
  final double subtitleWidth;

  const ShimmerCenteredPlaceholder({
    super.key,
    this.verticalPadding = 28,
    this.titleWidth = 190,
    this.subtitleWidth = 120,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: verticalPadding),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SkeletonBox(height: 14, width: titleWidth),
              const SizedBox(height: 10),
              SkeletonBox(height: 12, width: subtitleWidth),
            ],
          ),
        ),
      ),
    );
  }
}

class ShimmerButtonDots extends StatelessWidget {
  final double size;
  final double spacing;

  const ShimmerButtonDots({
    super.key,
    this.size = 7,
    this.spacing = 4,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      baseColor: Colors.white54,
      highlightColor: Colors.white,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(),
            SizedBox(width: spacing),
            _dot(),
            SizedBox(width: spacing),
            _dot(),
          ],
        ),
      ),
    );
  }

  Widget _dot() {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class ShimmerLinearBar extends StatelessWidget {
  final double height;
  final BorderRadiusGeometry borderRadius;

  const ShimmerLinearBar({
    super.key,
    this.height = 2,
    this.borderRadius = BorderRadius.zero,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE3EBF7),
          borderRadius: borderRadius,
        ),
      ),
    );
  }
}
