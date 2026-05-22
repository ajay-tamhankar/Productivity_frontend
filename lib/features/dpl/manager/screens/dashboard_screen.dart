import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/shimmer_skeleton.dart';
import '../../../auth/auth_provider.dart';
import '../../../auth/change_password_dialog.dart';
import '../../models/dpl_dashboard_summary.dart';
import '../providers/dpl_dashboard_provider.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry.dart';
import '../widgets/machine_summary_card.dart';

enum _DplDashboardMenu { refresh, changePassword, logout }

/// How often the dashboard re-pulls totals + per-machine state. Picked
/// to be slow enough to not hammer the API (a manager glancing at the
/// screen doesn't need sub-second freshness) but fast enough that an
/// active downtime started by a supervisor shows up within half a
/// minute. The ticker pauses when the app is backgrounded so it
/// doesn't burn battery / quota.
const _kDashboardRefreshInterval = Duration(seconds: 30);

class DplManagerDashboardScreen extends ConsumerStatefulWidget {
  const DplManagerDashboardScreen({super.key});

  @override
  ConsumerState<DplManagerDashboardScreen> createState() =>
      _DplManagerDashboardScreenState();
}

class _DplManagerDashboardScreenState
    extends ConsumerState<DplManagerDashboardScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  DateTime? _lastTick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startTicker();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopTicker();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Pause polling when the app drops to the background. Resume +
    // do an immediate refresh on the way back so the screen catches
    // up to whatever happened while it was hidden.
    if (state == AppLifecycleState.resumed) {
      _refreshOnce();
      _startTicker();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _stopTicker();
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_kDashboardRefreshInterval, (_) => _refreshOnce());
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _refreshOnce() {
    if (!mounted) return;
    ref.invalidate(dplDashboardSummaryProvider);
    ref.invalidate(dplDashboardMtdProvider);
    setState(() => _lastTick = DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final date = ref.watch(dplDashboardDateProvider);
    final summary = ref.watch(dplDashboardSummaryProvider);
    final user = ref.watch(authControllerProvider).asData?.value;

    final displayName = (user?.name.trim().isNotEmpty ?? false)
        ? user!.name
        : (user?.username ?? 'Manager');

    void handleMenu(_DplDashboardMenu action) {
      switch (action) {
        case _DplDashboardMenu.refresh:
          ref.invalidate(dplDashboardSummaryProvider);
          break;
        case _DplDashboardMenu.changePassword:
          showChangePasswordDialog(context, ref);
          break;
        case _DplDashboardMenu.logout:
          ref.read(authControllerProvider.notifier).logout();
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Daily Production'),
            _LiveIndicator(lastTick: _lastTick),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Pick date',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                ref.read(dplDashboardDateProvider.notifier).set(picked);
              }
            },
          ),
          PopupMenuButton<_DplDashboardMenu>(
            tooltip: displayName,
            onSelected: handleMenu,
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(
                  displayName,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _DplDashboardMenu.refresh,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.refresh),
                  title: Text('Refresh'),
                ),
              ),
              const PopupMenuItem(
                value: _DplDashboardMenu.changePassword,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.lock_reset_outlined),
                  title: Text('Change Password'),
                ),
              ),
              const PopupMenuItem(
                value: _DplDashboardMenu.logout,
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CircleAvatar(
                radius: 16,
                backgroundColor:
                    Theme.of(context).colorScheme.primary.withOpacity(0.14),
                child: Text(
                  displayName[0].toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFF2FFF9), Color(0xFFF7F2FF)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dplDashboardSummaryProvider);
            await ref.read(dplDashboardSummaryProvider.future);
          },
          child: summary.when(
            loading: () => const _DashboardSkeleton(),
            error: (e, _) => ListView(
              children: [
                DplErrorRetry(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(dplDashboardSummaryProvider),
                ),
              ],
            ),
            data: (res) {
              if (res.isError) {
                return ListView(
                  children: [
                    DplErrorRetry(
                      message: res.error ?? 'Failed to load dashboard.',
                      onRetry: () =>
                          ref.invalidate(dplDashboardSummaryProvider),
                    ),
                  ],
                );
              }
              final data = res.data ?? DplDashboardSummary.empty(date);
              return _DashboardBody(summary: data);
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dpl/manager/upload-plan'),
        icon: const Icon(Icons.upload_file_outlined),
        label: const Text('Upload Plan'),
      ),
    );
  }
}

/// Tiny "Live • updated 12s ago" badge under the app-bar title so the
/// manager can see the screen is polling and roughly when it last did.
class _LiveIndicator extends StatelessWidget {
  final DateTime? lastTick;
  const _LiveIndicator({required this.lastTick});

  String _label() {
    if (lastTick == null) return 'Live';
    final delta = DateTime.now().difference(lastTick!);
    if (delta.inSeconds < 5) return 'Live • just now';
    if (delta.inSeconds < 60) return 'Live • ${delta.inSeconds}s ago';
    return 'Live • ${delta.inMinutes}m ago';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFF15803D),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          _label(),
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF5D6A7A),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DplDashboardSummary summary;

  const _DashboardBody({required this.summary});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('EEEE, dd MMM yyyy');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          dateFmt.format(summary.date),
          style: const TextStyle(
            color: Color(0xFF5D6A7A),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _KpiStrip(summary: summary),
        const SizedBox(height: 14),
        _TotalsCard(summary: summary, fmt: fmt),
        const SizedBox(height: 16),
        const Text(
          'Machines',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (summary.machines.isEmpty)
          const DplEmptyState(
            icon: Icons.precision_manufacturing_outlined,
            title: 'No machines configured',
            message: 'Upload a plan or set up machines from the Settings tab.',
          )
        else
          ...summary.machines.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: DplMachineSummaryCard(
                summary: m,
                onTap: m.planId == null
                    ? null
                    : () => context.push('/dpl/manager/plans/${m.planId}'),
              ),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

/// Horizontally-scrollable strip of compact KPI cards shown at the top
/// of the Manager Dashboard. Each card reads from a different provider
/// so they update independently:
///
///   * Today   — `summary` passed in from the dashboard summary provider
///   * MTD     — `dplDashboardMtdProvider` (reportDplChart cumulative)
///   * Downtime today — derived from MTD's day cells for `summary.date`
class _KpiStrip extends ConsumerWidget {
  final DplDashboardSummary summary;

  const _KpiStrip({required this.summary});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mtdAsync = ref.watch(dplDashboardMtdProvider);
    final fmt = NumberFormat.decimalPattern();

    // ---- Today (selected date) ----
    final todayCard = _KpiCard(
      label: 'TODAY',
      sublabel: DateFormat('dd MMM').format(summary.date),
      ratioActual: summary.totalActualQty,
      ratioPlan: summary.totalPlanQty,
      pct: summary.completionPct,
      color: const Color(0xFF1D4ED8),
      icon: Icons.today_outlined,
      fmt: fmt,
    );

    // ---- MTD ----
    final mtd = mtdAsync.asData?.value.data;
    final mtdLoading = mtdAsync.isLoading;
    final mtdError = mtdAsync.hasError ||
        (mtd == null && mtdAsync.asData?.value.isError == true);

    Widget mtdCard;
    if (mtdLoading && mtd == null) {
      mtdCard = const _KpiCardSkeleton(
        label: 'MTD',
        sublabel: 'Cumulative till date',
        icon: Icons.calendar_month_outlined,
        color: Color(0xFF047857),
      );
    } else if (mtdError || mtd == null) {
      mtdCard = _KpiCard(
        label: 'MTD',
        sublabel: 'Cumulative till date',
        ratioActual: 0,
        ratioPlan: 0,
        pct: 0,
        color: const Color(0xFF047857),
        icon: Icons.calendar_month_outlined,
        fmt: fmt,
      );
    } else {
      mtdCard = _KpiCard(
        label: 'MTD',
        sublabel: 'Cumulative till date',
        ratioActual: mtd.cumulative.actualQty,
        ratioPlan: mtd.cumulative.planQty,
        pct: mtd.cumulative.achievementPct,
        color: const Color(0xFF047857),
        icon: Icons.calendar_month_outlined,
        fmt: fmt,
      );
    }

    // ---- Downtime today (sum of all machine summary cells) ----
    // The dashboard summary doesn't carry downtime per machine in the
    // current shape, so we surface today's downtime from the MTD chart
    // by picking out today's cells.
    int downtimeTodayMin = 0;
    if (mtd != null) {
      final today = summary.date;
      for (final row in mtd.rows) {
        for (final cell in row.daily) {
          if (cell.date.year == today.year &&
              cell.date.month == today.month &&
              cell.date.day == today.day) {
            downtimeTodayMin += cell.downtimeMinutes;
          }
        }
      }
    }

    final downtimeCard = _KpiCardSimple(
      label: 'DOWNTIME',
      sublabel: 'Today',
      value: _formatHrsMin(downtimeTodayMin),
      icon: Icons.timer_off_outlined,
      color: const Color(0xFFB45309),
    );

    final cards = <Widget>[todayCard, mtdCard, downtimeCard];
    final mobile = MediaQuery.of(context).size.width < 600;

    if (!mobile) {
      // Tablet / desktop — 3-up grid (or wrap on narrow tablet).
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards
            .map((c) => SizedBox(width: 200, child: c))
            .toList(),
      );
    }

    // Phones — fit all three KPIs in one row so nothing scrolls
    // off-screen. IntrinsicHeight equalises card heights regardless
    // of which one has the tallest content, Expanded splits the
    // available width evenly. Card internals are tuned to render
    // legibly at ~110dp width (see _KpiCard / _KpiCardSimple).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            Expanded(child: cards[i]),
            if (i < cards.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  static String _formatHrsMin(int totalMinutes) {
    if (totalMinutes <= 0) return '0m';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }
}

/// KPI card with an actual / plan ratio + completion % + tiny progress bar.
class _KpiCard extends StatelessWidget {
  final String label;
  final String sublabel;
  final int ratioActual;
  final int ratioPlan;
  final double pct;
  final Color color;
  final IconData icon;
  final NumberFormat fmt;

  const _KpiCard({
    required this.label,
    required this.sublabel,
    required this.ratioActual,
    required this.ratioPlan,
    required this.pct,
    required this.color,
    required this.icon,
    required this.fmt,
  });

  Color _achColor(double p) {
    if (ratioPlan == 0) return const Color(0xFF5D6A7A);
    if (p >= 1.0) return const Color(0xFF1D4ED8);
    if (p >= 0.9) return const Color(0xFF047857);
    if (p >= 0.7) return const Color(0xFFB45309);
    return const Color(0xFFB3261E);
  }

  @override
  Widget build(BuildContext context) {
    final pctRounded = (pct * 100).round();
    final achColor = _achColor(pct);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFFE2EAF6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.4,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        color: Color(0xFF5D6A7A),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Text(
                ratioPlan == 0 ? '—' : '$pctRounded%',
                style: TextStyle(
                  color: achColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Big number scales to whatever width is available so the
          // card never overflows on narrow viewports.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black),
                children: [
                  TextSpan(
                    text: fmt.format(ratioActual),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  TextSpan(
                    text: ' / ${fmt.format(ratioPlan)}',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Color(0xFF5D6A7A),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: const Color(0xFFEEF1F5),
              valueColor: AlwaysStoppedAnimation(achColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Simpler KPI card — single big value (no ratio).
class _KpiCardSimple extends StatelessWidget {
  final String label;
  final String sublabel;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCardSimple({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFFE2EAF6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, color: color, size: 14),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.4,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        color: Color(0xFF5D6A7A),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontFamily: 'monospace',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Matches the progress-bar row of the ratio card so all
          // three cards in the row line up to the same height.
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _KpiCardSkeleton extends StatelessWidget {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;

  const _KpiCardSkeleton({
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: const Color(0xFFE2EAF6)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 0.6,
                      ),
                    ),
                    Text(
                      sublabel,
                      style: const TextStyle(
                        color: Color(0xFF5D6A7A),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SkeletonBox(height: 20, width: 120),
          const SizedBox(height: 6),
          const SkeletonBox(height: 4, width: double.infinity),
        ],
      ),
    );
  }
}

class _TotalsCard extends StatelessWidget {
  final DplDashboardSummary summary;
  final NumberFormat fmt;

  const _TotalsCard({required this.summary, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final pct = (summary.completionPct * 100).round();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _BigStat(
                  label: 'Plan Qty',
                  value: fmt.format(summary.totalPlanQty),
                  color: const Color(0xFF1D4ED8),
                ),
              ),
              Expanded(
                child: _BigStat(
                  label: 'Actual Qty',
                  value: fmt.format(summary.totalActualQty),
                  color: const Color(0xFF047857),
                ),
              ),
              Expanded(
                child: _BigStat(
                  label: 'Completion',
                  value: '$pct%',
                  color: const Color(0xFFB45309),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: summary.completionPct,
              minHeight: 8,
              backgroundColor: const Color(0xFFEEF1F5),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _BigStat({
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
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
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

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(height: 14, width: 180),
        SizedBox(height: 14),
        SkeletonCard(),
        SizedBox(height: 14),
        SkeletonBox(height: 14, width: 100),
        SizedBox(height: 10),
        SkeletonList(count: 3),
      ],
    );
  }
}
