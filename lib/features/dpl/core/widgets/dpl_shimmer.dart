import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../design/dpl_theme.dart';

/// Loading skeleton block. Used as a building block for card-shaped
/// shimmers — keep skeletons matching the actual layout so the
/// page doesn't visibly jump on data arrival.
class DplShimmer extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const DplShimmer({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = DplRadius.sm,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF3F4F6),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton matching the shape of a hero stat card (label + 3 stat
/// tiles + a progress bar). Use during the first load on the manager
/// and supervisor dashboards.
class DplHeroCardShimmer extends StatelessWidget {
  const DplHeroCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DplSpacing.lg),
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: BorderRadius.circular(DplRadius.lg),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DplShimmer(width: 120, height: 14),
          const SizedBox(height: DplSpacing.lg),
          Row(
            children: List.generate(
              3,
              (i) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 2 ? DplSpacing.md : 0),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DplShimmer(width: 50, height: 10),
                      SizedBox(height: 6),
                      DplShimmer(width: 70, height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: DplSpacing.lg),
          const DplShimmer(height: 8, radius: 999),
        ],
      ),
    );
  }
}

/// Skeleton matching the per-machine card.
class DplMachineCardShimmer extends StatelessWidget {
  const DplMachineCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: DplSpacing.md),
      padding: const EdgeInsets.all(DplSpacing.lg),
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: BorderRadius.circular(DplRadius.lg),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              DplShimmer(width: 140, height: 18),
              DplShimmer(width: 80, height: 22, radius: 999),
            ],
          ),
          const SizedBox(height: DplSpacing.md),
          Row(
            children: const [
              Expanded(child: DplShimmer(width: 80, height: 24)),
              SizedBox(width: DplSpacing.md),
              Expanded(child: DplShimmer(width: 80, height: 24)),
              SizedBox(width: DplSpacing.md),
              Expanded(child: DplShimmer(width: 80, height: 24)),
            ],
          ),
          const SizedBox(height: DplSpacing.md),
          const DplShimmer(height: 8, radius: 999),
        ],
      ),
    );
  }
}

/// Generic list of N machine-card shimmers — drop-in for the loading
/// state of any dashboard list.
class DplDashboardShimmer extends StatelessWidget {
  final int machineCount;
  const DplDashboardShimmer({super.key, this.machineCount = 3});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(DplSpacing.lg),
      child: Column(
        children: [
          const DplHeroCardShimmer(),
          const SizedBox(height: DplSpacing.lg),
          for (int i = 0; i < machineCount; i++)
            const DplMachineCardShimmer(),
        ],
      ),
    );
  }
}
