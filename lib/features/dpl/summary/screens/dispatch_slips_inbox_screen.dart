import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/shimmer_skeleton.dart';
import '../../../auth/auth_provider.dart';
import '../../core/design/dpl_theme.dart';
import '../../core/dpl_constants.dart';
import '../../manager/widgets/empty_state.dart';
import '../../manager/widgets/error_retry.dart';
import '../../models/dpl_dispatch_slip.dart';
import '../providers/dispatch_slips_provider.dart';
import '../widgets/dispatch_slip_status_badge.dart';
import 'dispatch_slip_detail_screen.dart';

/// Lists dispatch slips with role-aware status tabs:
///   * QA → "Pending QA" inbox + history
///   * PDI → "Pending PDI" inbox + history
///   * Dispatch → "My slips" (all statuses)
///   * Manager → everything, all statuses
///
/// Embedded inside [DplSummaryShell] (no own AppBar by default) so the
/// shell's standard branded AppBar wraps it.
class DispatchSlipsInboxScreen extends ConsumerStatefulWidget {
  final bool showAppBar;
  const DispatchSlipsInboxScreen({super.key, this.showAppBar = false});

  @override
  ConsumerState<DispatchSlipsInboxScreen> createState() =>
      _DispatchSlipsInboxScreenState();
}

class _DispatchSlipsInboxScreenState
    extends ConsumerState<DispatchSlipsInboxScreen> {
  late final TextEditingController _searchCtrl;
  Timer? _debounce;
  bool _didApplyRoleDefault = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController(
      text: ref.read(dplDispatchSlipFiltersProvider).query,
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Pick the "inbox" status for the user's role the first time we
  /// build. Runs once so the user can still flip between statuses
  /// afterwards without us overriding their choice on rebuild.
  void _applyRoleDefaultIfNeeded(String role) {
    if (_didApplyRoleDefault) return;
    _didApplyRoleDefault = true;
    final current = ref.read(dplDispatchSlipFiltersProvider).status;
    if (current != null) return;
    String? defaultStatus;
    if (AppConstants.isDplQaRole(role)) {
      defaultStatus = DplDispatchSlipStatus.pendingQa;
    } else if (AppConstants.isDplPdiRole(role)) {
      defaultStatus = DplDispatchSlipStatus.pendingPdi;
    }
    if (defaultStatus != null) {
      Future.microtask(() {
        if (!mounted) return;
        ref
            .read(dplDispatchSlipFiltersProvider.notifier)
            .setStatus(defaultStatus);
      });
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(dplDispatchSlipFiltersProvider.notifier).setQuery(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authControllerProvider).asData?.value?.role ?? '';
    _applyRoleDefaultIfNeeded(role);

    final filters = ref.watch(dplDispatchSlipFiltersProvider);
    final pageAsync = ref.watch(dplDispatchSlipsProvider);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusTabs(role: role),
        _SearchBar(
          controller: _searchCtrl,
          onChanged: _onSearchChanged,
          onClear: () {
            _searchCtrl.clear();
            ref.read(dplDispatchSlipFiltersProvider.notifier).setQuery('');
          },
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dplDispatchSlipsProvider);
              try {
                await ref.read(dplDispatchSlipsProvider.future);
              } catch (_) {}
            },
            child: pageAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: SkeletonList(count: 5),
              ),
              error: (e, _) => ListView(
                children: [
                  DplErrorRetry(
                    message: e.toString(),
                    onRetry: () => ref.invalidate(dplDispatchSlipsProvider),
                  ),
                ],
              ),
              data: (res) {
                if (res.isError) {
                  return ListView(
                    children: [
                      DplErrorRetry(
                        message: res.error ?? 'Failed to load slips.',
                        onRetry: () =>
                            ref.invalidate(dplDispatchSlipsProvider),
                      ),
                    ],
                  );
                }
                final page = res.data ?? DplDispatchSlipPage.empty();
                if (page.items.isEmpty) {
                  return ListView(
                    children: [
                      const SizedBox(height: 60),
                      DplEmptyState(
                        icon: Icons.inbox_outlined,
                        title: _emptyTitleFor(filters.status, role),
                        message: _emptyMessageFor(filters.status, role),
                      ),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: page.items.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    if (i == page.items.length) {
                      return _Pagination(
                        page: page,
                        onChange: (p) => ref
                            .read(dplDispatchSlipFiltersProvider.notifier)
                            .setPage(p),
                      );
                    }
                    return _SlipRowCard(slip: page.items[i]);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );

    if (!widget.showAppBar) return body;
    return Scaffold(
      backgroundColor: DplColors.pageBg,
      appBar: AppBar(
        title: const Text('Dispatch Slips'),
      ),
      body: body,
    );
  }

  String _emptyTitleFor(String? status, String role) {
    if (status == DplDispatchSlipStatus.pendingQa) return 'QA inbox is clear';
    if (status == DplDispatchSlipStatus.pendingPdi) return 'PDI inbox is clear';
    if (AppConstants.isDplDispatchRole(role)) return 'No slips yet';
    return 'No slips found';
  }

  String _emptyMessageFor(String? status, String role) {
    if (status == DplDispatchSlipStatus.pendingQa) {
      return 'Nothing is waiting for QA approval right now.';
    }
    if (status == DplDispatchSlipStatus.pendingPdi) {
      return 'Nothing is waiting for PDI approval right now.';
    }
    if (AppConstants.isDplDispatchRole(role)) {
      return 'Tap "Request Dispatch Slip" on a production bucket to start.';
    }
    return 'Try adjusting the filters above.';
  }
}

/// Status tab strip — shows counts so QA / PDI can see their queue
/// depth at a glance. "All" tab clears the status filter.
class _StatusTabs extends ConsumerWidget {
  final String role;
  const _StatusTabs({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(dplDispatchSlipFiltersProvider);
    final pageAsync = ref.watch(dplDispatchSlipsProvider);
    final totals = pageAsync.asData?.value.data?.totals ??
        const DplDispatchSlipTotals();

    // Role-specific ordering: each role's primary inbox first, then the
    // others, then All. Dispatch sees all open + closed states.
    final List<_StatusTabSpec> tabs;
    if (AppConstants.isDplQaRole(role)) {
      tabs = [
        _StatusTabSpec(DplDispatchSlipStatus.pendingQa, 'Pending QA',
            totals.pendingQa),
        _StatusTabSpec(DplDispatchSlipStatus.pendingPdi, 'Pending PDI',
            totals.pendingPdi),
        _StatusTabSpec(DplDispatchSlipStatus.approved, 'Approved',
            totals.approved),
        _StatusTabSpec(DplDispatchSlipStatus.rejected, 'Rejected',
            totals.rejected),
        const _StatusTabSpec(null, 'All', null),
      ];
    } else if (AppConstants.isDplPdiRole(role)) {
      tabs = [
        _StatusTabSpec(DplDispatchSlipStatus.pendingPdi, 'Pending PDI',
            totals.pendingPdi),
        _StatusTabSpec(DplDispatchSlipStatus.approved, 'Approved',
            totals.approved),
        _StatusTabSpec(DplDispatchSlipStatus.dispatched, 'Dispatched',
            totals.dispatched),
        _StatusTabSpec(DplDispatchSlipStatus.rejected, 'Rejected',
            totals.rejected),
        const _StatusTabSpec(null, 'All', null),
      ];
    } else {
      tabs = [
        const _StatusTabSpec(null, 'All', null),
        _StatusTabSpec(DplDispatchSlipStatus.pendingQa, 'Pending QA',
            totals.pendingQa),
        _StatusTabSpec(DplDispatchSlipStatus.pendingPdi, 'Pending PDI',
            totals.pendingPdi),
        _StatusTabSpec(DplDispatchSlipStatus.approved, 'Approved',
            totals.approved),
        _StatusTabSpec(DplDispatchSlipStatus.dispatched, 'Dispatched',
            totals.dispatched),
        _StatusTabSpec(DplDispatchSlipStatus.rejected, 'Rejected',
            totals.rejected),
      ];
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          for (final t in tabs) ...[
            _StatusChip(
              label: t.label,
              count: t.count,
              selected: filters.status == t.status,
              onTap: () => ref
                  .read(dplDispatchSlipFiltersProvider.notifier)
                  .setStatus(t.status),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _StatusTabSpec {
  final String? status;
  final String label;
  final int? count;
  const _StatusTabSpec(this.status, this.label, this.count);
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? DplColors.primary : DplColors.cardBg,
            border: Border.all(
              color: selected ? DplColors.primary : DplColors.divider,
            ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? DplColors.textInverse
                      : DplColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
                ),
              ),
              if (count != null && count! > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.22)
                        : DplColors.primaryTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected
                          ? DplColors.textInverse
                          : DplColors.primaryDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
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

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search slip no, machine, part…',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClear,
                ),
          filled: true,
          fillColor: DplColors.cardBg,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DplColors.divider),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: DplColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: DplColors.primary,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _SlipRowCard extends StatelessWidget {
  final DplDispatchSlip slip;
  const _SlipRowCard({required this.slip});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DispatchSlipDetailScreen(slipId: slip.id),
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: DplColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DplColors.divider),
            boxShadow: DplShadows.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      slip.slipNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DispatchSlipStatusBadge(status: slip.status),
                ],
              ),
              const SizedBox(height: 6),
              // Multi-item slips compress to "Machine · N items · X NOS"
              // so the tile stays one-line scannable. Single-item slips
              // keep the original "Machine · Qty X" + part label below.
              Text(
                slip.isSingleItem
                    ? '${slip.machineLabel} • Qty ${fmt.format(slip.qty)}'
                    : '${slip.machineLabel} • ${slip.items.length} items '
                        '• ${fmt.format(slip.totalQty)} NOS',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                slip.partLabel,
                style: const TextStyle(
                  color: DplColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Customer P/N is only meaningful on single-item slips.
              // Multi-item slips render multiple P/Ns in the items
              // list — surfacing just the first one here would be
              // misleading, so hide.
              if (slip.isSingleItem && slip.customerPartNo.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  slip.customerPartNo,
                  style: const TextStyle(
                    color: DplColors.textTertiary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 13,
                    color: DplColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      slip.requestedBy?.name ?? '-',
                      style: const TextStyle(
                        color: DplColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (slip.requestedAt != null)
                    Text(
                      dateFmt.format(slip.requestedAt!.toLocal()),
                      style: const TextStyle(
                        color: DplColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final DplDispatchSlipPage page;
  final ValueChanged<int> onChange;
  const _Pagination({required this.page, required this.onChange});

  @override
  Widget build(BuildContext context) {
    if (page.totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Showing ${page.items.length} of ${page.total}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: DplColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed:
                page.page > 1 ? () => onChange(page.page - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Prev'),
          ),
          const SizedBox(width: 12),
          Text(
            'Page ${page.page} of ${page.totalPages}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: page.hasMore ? () => onChange(page.page + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
