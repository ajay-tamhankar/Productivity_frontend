import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/shimmer_skeleton.dart';
import '../../core/widgets/dpl_refresh_icon_button.dart';
import '../../manager/widgets/empty_state.dart';
import '../../manager/widgets/error_retry.dart';
import '../../models/dpl_supervisor_today.dart';
import '../providers/today_plans_provider.dart';
import '../widgets/machine_tile_large.dart';

/// Today tab — list of machines assigned to this supervisor.
class SupervisorDashboardScreen extends ConsumerWidget {
  const SupervisorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(todayPlansProvider);
    final dateFmt = DateFormat('EEEE, dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text('Today — ${dateFmt.format(DateTime.now())}'),
        actions: [
          DplRefreshIconButton(
            onRefresh: () async {
              ref.invalidate(todayPlansProvider);
              try {
                await ref.read(todayPlansProvider.future);
              } catch (_) {}
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(todayPlansProvider);
          // Wait one tick so the stream's first emission lands.
          await Future<void>.delayed(const Duration(milliseconds: 200));
        },
        child: async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonList(count: 3),
          ),
          error: (e, _) => ListView(
            children: [
              DplErrorRetry(
                message: e.toString(),
                onRetry: () => ref.invalidate(todayPlansProvider),
              ),
            ],
          ),
          data: (res) {
            if (res.isError) {
              return ListView(
                children: [
                  DplErrorRetry(
                    message: res.error ?? 'Failed to load today\'s plans.',
                    onRetry: () => ref.invalidate(todayPlansProvider),
                  ),
                ],
              );
            }
            final today =
                res.data ?? SupervisorTodayResponse.empty(DateTime.now());
            if (today.plans.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  DplEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'No plans for today',
                    message:
                        'No plans have been assigned to you yet. Talk to your manager.',
                  ),
                ],
              );
            }
            return _DashboardBody(today: today);
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final SupervisorTodayResponse today;

  const _DashboardBody({required this.today});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.decimalPattern();
    final totalPlan =
        today.plans.fold<int>(0, (a, p) => a + p.totalPlanQty);
    final totalActual =
        today.plans.fold<int>(0, (a, p) => a + p.totalActualQty);
    final pct = totalPlan <= 0
        ? 0
        : ((totalActual / totalPlan) * 100).round();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EAF6)),
          ),
          child: Row(
            children: [
              _BigKv(
                label: 'Plan',
                value: fmt.format(totalPlan),
                color: const Color(0xFF1D4ED8),
              ),
              const SizedBox(width: 16),
              _BigKv(
                label: 'Actual',
                value: fmt.format(totalActual),
                color: const Color(0xFF047857),
              ),
              const Spacer(),
              _BigKv(
                label: 'Completion',
                value: '$pct%',
                color: const Color(0xFFB45309),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final plan in today.plans)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MachineTileLarge(
              plan: plan,
              onTap: () =>
                  context.push('/dpl/supervisor/machine/${plan.id}'),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _BigKv extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BigKv({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5D6A7A),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ],
    );
  }
}
