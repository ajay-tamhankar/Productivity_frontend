import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme_mode_provider.dart';
import '../../data/models/production_entry_model.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/auth/change_password_dialog.dart';
import 'operator_feed_provider.dart';
import 'operator_stats_provider.dart';

enum _OperatorMenuAction { refresh, toggleTheme, changePassword, logout }

class OperatorDashboardScreen extends ConsumerWidget {
  const OperatorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const _OperatorHomeView();
}

class _OperatorHomeView extends ConsumerStatefulWidget {
  const _OperatorHomeView();

  @override
  ConsumerState<_OperatorHomeView> createState() => _OperatorHomeViewState();
}

class _OperatorHomeViewState extends ConsumerState<_OperatorHomeView>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final NumberFormat _countFormat = NumberFormat.decimalPattern();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshAll();
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 220) {
      ref.read(operatorFeedControllerProvider.notifier).loadMore();
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(operatorFeedControllerProvider.notifier).refresh(),
      ref.refresh(operatorStatsProvider.future),
    ]);
  }

  String _formatError(Object error) {
    final raw = error.toString();
    const prefix = 'Exception:';
    if (raw.startsWith(prefix)) {
      return raw.substring(prefix.length).trim();
    }
    return raw;
  }

  void _handleMenuAction(
    _OperatorMenuAction action,
  ) {
    switch (action) {
      case _OperatorMenuAction.refresh:
        _refreshAll();
        break;
      case _OperatorMenuAction.toggleTheme:
        ref.read(themeModeProvider.notifier).toggleThemeMode();
        break;
      case _OperatorMenuAction.changePassword:
        showChangePasswordDialog(context, ref);
        break;
      case _OperatorMenuAction.logout:
        ref.read(authControllerProvider.notifier).logout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final feedStateAsync = ref.watch(operatorFeedControllerProvider);
    final statsAsync = ref.watch(operatorStatsProvider);
    final authState = ref.watch(authControllerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final user = authState.asData?.value;
    final name = user?.name.trim() ?? '';
    final username = user?.username.trim() ?? '';
    final displayName = name.isNotEmpty
        ? name
        : username.isNotEmpty
            ? username
            : 'Operator';
    final isDarkMode = themeMode == ThemeMode.dark;
    final isCompactAppBar = MediaQuery.of(context).size.width < 760;
    final userInitial = displayName.isEmpty ? 'U' : displayName[0].toUpperCase();

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Operator Dashboard'),
        actions: isCompactAppBar
            ? [
                PopupMenuButton<_OperatorMenuAction>(
                  tooltip: displayName,
                  onSelected: _handleMenuAction,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      enabled: false,
                      child: Text(
                        displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: _OperatorMenuAction.refresh,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.refresh),
                        title: Text('Refresh'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _OperatorMenuAction.toggleTheme,
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                        ),
                        title: Text(isDarkMode ? 'Light Mode' : 'Dark Mode'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _OperatorMenuAction.changePassword,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.lock_reset_outlined),
                        title: Text('Change Password'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: _OperatorMenuAction.logout,
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
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.14),
                      child: Text(
                        userInitial,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ]
            : [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 120),
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshAll,
                  tooltip: 'Refresh',
                ),
                IconButton(
                  icon: Icon(
                    isDarkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  ),
                  onPressed: () => ref.read(themeModeProvider.notifier).toggleThemeMode(),
                  tooltip: isDarkMode ? 'Switch to light mode' : 'Switch to dark mode',
                ),
                IconButton(
                  icon: const Icon(Icons.lock_reset_outlined),
                  onPressed: () => showChangePasswordDialog(context, ref),
                  tooltip: 'Change Password',
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    ref.read(authControllerProvider.notifier).logout();
                  },
                  tooltip: 'Logout',
                ),
              ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F8FF), Color(0xFFE8FFF6), Color(0xFFE9F0FF)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              _HeroStatsBanner(statsAsync: statsAsync, countFormat: _countFormat),
              const SizedBox(height: 20),
              Text(
                'Performance Snapshot',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              statsAsync.when(
                loading: () => const _StatsLoadingView(),
                error: (error, _) => _SectionErrorCard(
                  title: 'Could not load stats',
                  message: _formatError(error),
                  onRetry: () => ref.refresh(operatorStatsProvider),
                ),
                data: (stats) => _OperatorStatsGrid(
                  stats: stats,
                  countFormat: _countFormat,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Recent Entries',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              feedStateAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _SectionErrorCard(
                  title: 'Could not load recent entries',
                  message: _formatError(error),
                  onRetry: () =>
                      ref.read(operatorFeedControllerProvider.notifier).refresh(),
                ),
                data: (feed) {
                  if (feed.entries.isEmpty) {
                    return const _SectionEmptyCard(
                      title: 'No submissions yet',
                      subtitle: 'Tap "New Entry" to add your first production log.',
                    );
                  }

                  return Column(
                    children: [
                      for (final entry in feed.entries)
                        _OperatorEntryCard(entry: entry),
                      if (feed.isLoadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/new-entry');
          if (!mounted) return;
          await _refreshAll();
        },
        label: const Text('New Entry'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _HeroStatsBanner extends StatelessWidget {
  final AsyncValue<OperatorStats> statsAsync;
  final NumberFormat countFormat;

  const _HeroStatsBanner({
    required this.statsAsync,
    required this.countFormat,
  });

  @override
  Widget build(BuildContext context) {
    final stats = statsAsync.asData?.value;
    final totalProduction = stats?.totalProduction ?? 0;
    final totalRejection = stats?.totalRejection ?? 0;
    final avgParts = stats?.averagePartsPerHour ?? 0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF1546A0), Color(0xFF176CA6), Color(0xFF1A8D78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3A8A).withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today at a glance',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Track your output and maintain quality targets in real time.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _HeroBadge(
                label: 'Production',
                value: countFormat.format(totalProduction),
              ),
              _HeroBadge(
                label: 'Rejection',
                value: countFormat.format(totalRejection),
              ),
              _HeroBadge(
                label: 'Avg Parts/Hr',
                value: avgParts.toStringAsFixed(0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;
  final String value;

  const _HeroBadge({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorStatsGrid extends StatelessWidget {
  final OperatorStats stats;
  final NumberFormat countFormat;

  const _OperatorStatsGrid({
    required this.stats,
    required this.countFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final bool twoColumns = constraints.maxWidth > 640;
            final double cardWidth =
                twoColumns ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _StatCard(
                    title: 'Total Production',
                    value: countFormat.format(stats.totalProduction),
                    subtitle: 'Units completed',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF185ADB),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _StatCard(
                    title: 'Total Rejection',
                    value: countFormat.format(stats.totalRejection),
                    subtitle: 'Units rejected',
                    icon: Icons.rule_folder_outlined,
                    color: const Color(0xFFD64545),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _StatCard(
                    title: 'Running Hours',
                    value: stats.totalRunningHours.toStringAsFixed(2),
                    subtitle: 'Total hours',
                    icon: Icons.timer_outlined,
                    color: const Color(0xFF0E9F6E),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _StatCard(
                    title: 'Average Parts/Hr',
                    value: stats.averagePartsPerHour.toStringAsFixed(1),
                    subtitle: 'Throughput rate',
                    icon: Icons.speed_outlined,
                    color: const Color(0xFF7A4DCC),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        _RejectionReasonCard(rejectionReasons: stats.rejectionReasons),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF4C596A),
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF687789),
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

class _RejectionReasonCard extends StatelessWidget {
  final List<OperatorRejectionReason> rejectionReasons;

  const _RejectionReasonCard({
    required this.rejectionReasons,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rejection Reasons',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (rejectionReasons.isEmpty)
            const Text(
              'No rejection reasons recorded.',
              style: TextStyle(color: Color(0xFF5F6B7A)),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: rejectionReasons
                  .map(
                    (reason) => Chip(
                      label: Text('${reason.reason}: ${reason.count}'),
                      backgroundColor: const Color(0xFFFFF1EE),
                      side: const BorderSide(color: Color(0xFFFFD9D0)),
                      labelStyle: const TextStyle(
                        color: Color(0xFF7B2F22),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _StatsLoadingView extends StatelessWidget {
  const _StatsLoadingView();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _SectionErrorCard extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const _SectionErrorCard({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD6D6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xFFA1312D),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: Color(0xFF8A2A24)),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SectionEmptyCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionEmptyCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF5F6B7A)),
          ),
        ],
      ),
    );
  }
}

class _OperatorEntryCard extends StatelessWidget {
  final ProductionEntryModel entry;

  const _OperatorEntryCard({
    required this.entry,
  });

  String _safeValue(String value) => value.trim().isEmpty ? '-' : value;

  String _formatDate(String rawDate) {
    final parsed = DateTime.tryParse(rawDate);
    if (parsed == null) return rawDate.trim().isEmpty ? '-' : rawDate;
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final approval = _safeValue(entry.approvalStatus ?? 'Pending');
    final date = _formatDate(entry.entryDate);
    final machine = _safeValue(entry.machineName ?? entry.machineId);
    final item = _safeValue(entry.itemDescription ?? entry.itemId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3EAF5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF185ADB).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.precision_manufacturing_outlined,
              color: Color(0xFF185ADB),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$machine | $item',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Date: $date | Shift: ${_safeValue(entry.shift)}',
                  style: const TextStyle(color: Color(0xFF5D6A7A)),
                ),
                const SizedBox(height: 3),
                Text(
                  'Actual Qty: ${entry.actualQuantity} | Rejection: ${entry.rejectionQuantity}',
                  style: const TextStyle(color: Color(0xFF5D6A7A)),
                ),
                const SizedBox(height: 3),
                Text(
                  'Running Hours: ${entry.runningHours.toStringAsFixed(2)} | Parts/Hr: ${entry.partsPerHour.toStringAsFixed(1)}',
                  style: const TextStyle(color: Color(0xFF5D6A7A)),
                ),
                const SizedBox(height: 3),
                Text(
                  'Weight (kg): ${entry.weightInKGs.toStringAsFixed(1)}',
                  style: const TextStyle(color: Color(0xFF5D6A7A)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ApprovalStatusPill(status: approval),
        ],
      ),
    );
  }
}

class _ApprovalStatusPill extends StatelessWidget {
  final String status;

  const _ApprovalStatusPill({
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = status.toUpperCase();

    Color bgColor;
    Color textColor;

    if (normalized == 'APPROVED') {
      bgColor = const Color(0xFFE7F8EF);
      textColor = const Color(0xFF127944);
    } else if (normalized == 'REJECTED') {
      bgColor = const Color(0xFFFFEAEA);
      textColor = const Color(0xFFB32929);
    } else {
      bgColor = const Color(0xFFFFF6E2);
      textColor = const Color(0xFF8D5A00);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}
