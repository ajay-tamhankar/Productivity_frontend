import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/shimmer_skeleton.dart';
import '../../core/design/dpl_theme.dart';
import '../../manager/widgets/empty_state.dart';
import '../../manager/widgets/error_retry.dart';
import '../../models/dpl_plant.dart';
import '../providers/plants_provider.dart';
import '../providers/production_summary_provider.dart';
import '../widgets/plant_card.dart';
import 'production_summary_screen.dart';

/// New "select a plant first" landing screen for the Dispatch / QA /
/// PDI shell. Replaces the old bucket-first production summary view.
///
/// The user picks one of the three plants → drills into its production
/// summary (filtered to that plant's machines). Slips, in turn, are
/// scoped to a single plant in the new multi-item flow, so plant
/// selection is the entry point for all dispatch work.
class PlantLandingScreen extends ConsumerWidget {
  final bool showAppBar;
  const PlantLandingScreen({super.key, this.showAppBar = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plantsAsync = ref.watch(dplPlantsProvider);

    final body = RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dplPlantsProvider);
        ref.invalidate(dplProductionSummaryProvider);
        try {
          await ref.read(dplPlantsProvider.future);
          await ref.read(dplProductionSummaryProvider.future);
        } catch (_) {}
      },
      child: CustomScrollView(
        slivers: [
          // Top — at-a-glance totals banner (Actual / Plan / Buckets /
          // Remaining + In pipeline / Dispatched / Rejected). Same
          // widget the production summary tab uses, so the numbers
          // stay perfectly consistent across both screens.
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          const SliverToBoxAdapter(child: ProductionTotalsBanner()),
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
          // Then — landing header + plant selection cards.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            sliver: SliverToBoxAdapter(child: const _LandingHeader()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          ..._buildPlantSection(context, ref, plantsAsync),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );

    if (!showAppBar) return body;
    return Scaffold(
      backgroundColor: DplColors.pageBg,
      appBar: AppBar(title: const Text('Select Plant')),
      body: body,
    );
  }

  /// Slivers for the plant-selection row. Returns the right slivers
  /// for whichever state the plants provider is in.
  List<Widget> _buildPlantSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<dynamic> async,
  ) {
    return async.when(
      loading: () => [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SkeletonList(count: 3),
          ),
        ),
      ],
      error: (e, _) => [
        SliverToBoxAdapter(
          child: DplErrorRetry(
            message: e.toString(),
            onRetry: () => ref.invalidate(dplPlantsProvider),
          ),
        ),
      ],
      data: (res) {
        if (res.isError) {
          return [
            SliverToBoxAdapter(
              child: DplErrorRetry(
                message: res.error ?? 'Failed to load plants.',
                onRetry: () => ref.invalidate(dplPlantsProvider),
              ),
            ),
          ];
        }
        final plants = (res.data ?? const <DplPlant>[]) as List<DplPlant>;
        if (plants.isEmpty) {
          return const [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: DplEmptyState(
                  icon: Icons.factory_outlined,
                  title: 'No plants configured',
                  message: 'Ask an admin to seed the plant mapping.',
                ),
              ),
            ),
          ];
        }
        return [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: plants.length,
              itemBuilder: (_, i) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: PlantCard(
                  plant: plants[i],
                  palette: _paletteFor(i),
                ),
              ),
            ),
          ),
        ];
      },
    );
  }

  /// Cycle three distinct accents across the three plant cards so the
  /// eye can distinguish them at a glance. Order is stable across
  /// sessions — same plant always gets the same accent.
  PlantCardPalette _paletteFor(int index) {
    switch (index % 3) {
      case 0:
        return const PlantCardPalette(
          accent: Color(0xFF6B1F8C),
          accentDark: Color(0xFF4A1163),
          surface: Color(0xFFF3E8F9),
          edge: Color(0xFFD8BFE9),
        );
      case 1:
        return const PlantCardPalette(
          accent: Color(0xFFB45309),
          accentDark: Color(0xFF7C3A05),
          surface: Color(0xFFFEF3C7),
          edge: Color(0xFFFCD9A1),
        );
      default:
        return const PlantCardPalette(
          accent: Color(0xFF0E7C66),
          accentDark: Color(0xFF064E40),
          surface: Color(0xFFD9F0E9),
          edge: Color(0xFFA4D9C8),
        );
    }
  }
}

class _LandingHeader extends StatelessWidget {
  const _LandingHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DplColors.primaryTint,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: DplColors.primary.withValues(alpha: 0.15),
              ),
            ),
            child: const Icon(
              Icons.factory_outlined,
              size: 18,
              color: DplColors.primaryDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select a plant', style: DplText.h3()),
                const SizedBox(height: 2),
                const Text(
                  'Pick the plant you want to dispatch from. '
                  'Each slip you create is scoped to one plant.',
                  style: TextStyle(
                    color: DplColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
