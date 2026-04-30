import 'package:flutter/material.dart';

class AppShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const AppShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1100),
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
              begin: Alignment(-1.0 + (2 * _controller.value), 0),
              end: Alignment(0.0 + (2 * _controller.value), 0),
              colors: <Color>[
                baseColor.withOpacity(0.95),
                highlightColor.withOpacity(0.98),
                baseColor.withOpacity(0.95),
              ],
              stops: const <double>[0.25, 0.5, 0.75],
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

class SkeletonCard extends StatelessWidget {
  final BorderRadiusGeometry borderRadius;
  const SkeletonCard({
    super.key,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: borderRadius,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(height: 14, width: 180),
            const SizedBox(height: 8),
            SkeletonBox(height: 12, width: 120),
            const SizedBox(height: 12),
            Row(
              children: [
                SkeletonBox(height: 10, width: 60, borderRadius: BorderRadius.circular(999)),
                const SizedBox(width: 8),
                SkeletonBox(height: 10, width: 60, borderRadius: BorderRadius.circular(999)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  final int count;
  final double spacing;
  const SkeletonList({super.key, this.count = 4, this.spacing = 10});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (i) => Padding(
          padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : spacing),
          child: const SkeletonCard(),
        ),
      ),
    );
  }
}
