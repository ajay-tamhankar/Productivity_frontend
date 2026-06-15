import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/dpl_theme.dart';
import '../../core/dpl_api_service.dart';
import '../../core/widgets/dpl_snack.dart';
import '../../models/dpl_dispatch_slip.dart';
import '../../models/dpl_plant.dart';
import '../../models/dpl_production_summary.dart';
import '../providers/dispatch_slips_provider.dart';
import '../providers/production_summary_provider.dart';

/// Accent palette for a plant card. Lets the landing screen cycle
/// three distinct accents across the three plant cards so the eye can
/// distinguish them at a glance.
class PlantCardPalette {
  final Color accent;
  final Color accentDark;
  final Color surface;
  final Color edge;

  const PlantCardPalette({
    required this.accent,
    required this.accentDark,
    required this.surface,
    required this.edge,
  });
}

/// Full-form plant card — replaces the old "tap to drill in" plant
/// tile. Each card is a self-contained slip request:
///
///   ┌─────────────────────────────────────────────────────┐
///   │ ▌ 🏭  Plant Name                  [N machines]     │  Header
///   │ ▌    PLANT_CODE                                    │
///   │ ▌ ────────────────────────────────────────────     │
///   │ ▌  STATS    Actual  Plan  Done  In-prog  Pending   │  Stats row
///   │ ▌ ────────────────────────────────────────────     │
///   │ ▌  [ Machine ▾ ]                                   │  Form
///   │ ▌  [ Description ▾ smart search ]                  │
///   │ ▌  Customer P/N + Available qty (auto-filled)      │
///   │ ▌  [ Qty ____ ]                                    │
///   │ ▌  [ Vehicle no (optional) _______ ]               │
///   │ ▌  [ Notes (optional) ______________ ]             │
///   │ ▌  [ Reset ]                 [ ✈ Send to QA ]      │
///   └─────────────────────────────────────────────────────┘
///
/// Holds its own form state so three cards on the landing screen
/// don't fight over a single Notifier.
class PlantCard extends ConsumerStatefulWidget {
  final DplPlant plant;
  final PlantCardPalette palette;

  const PlantCard({
    super.key,
    required this.plant,
    required this.palette,
  });

  @override
  ConsumerState<PlantCard> createState() => _PlantCardState();
}

/// One line in the in-progress slip — a chosen bucket + the qty the
/// user has reserved against it. Multiple cart items get sent as a
/// single multi-item slip when the user hits "Send to QA".
class _CartItem {
  final DplProductionSummary bucket;
  final int qty;

  const _CartItem({required this.bucket, required this.qty});
}

class _PlantCardState extends ConsumerState<PlantCard> {
  late final TextEditingController _vehicleCtrl;
  late final TextEditingController _notesCtrl;

  int? _selectedMachineId;
  bool _submitting = false;
  String? _serverError;

  /// Items the user has added to this slip via the multi-select picker
  /// but not yet sent. One slip can carry multiple
  /// `(machine, part, qty)` lines so the user can spread a large
  /// dispatch across several parts when no single one has enough
  /// stock — e.g. need 927 NOS, top-rank part has 794 available,
  /// second part covers the remaining 133.
  final List<_CartItem> _cartItems = [];

  @override
  void initState() {
    super.initState();
    _vehicleCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    // Single-machine plants auto-select to skip a click.
    if (widget.plant.machines.length == 1) {
      _selectedMachineId = widget.plant.machines.first.id;
    } else if (widget.plant.machineIds.length == 1) {
      _selectedMachineId = widget.plant.machineIds.first;
    }
  }

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Sum of qty across every row currently in the cart. Drives the
  /// "Send to QA · N NOS" button label.
  int get _cartTotalQty =>
      _cartItems.fold<int>(0, (sum, it) => sum + it.qty);

  /// Cart commitments keyed by `partId` for the **currently selected
  /// machine**. Passed to the picker so its per-row "available" can
  /// subtract what's already queued — keeps the user from over-
  /// allocating one bucket across multiple cart entries before the
  /// request even hits the backend.
  Map<int, int> _cartCommitmentsForCurrentMachine() {
    final out = <int, int>{};
    for (final it in _cartItems) {
      if (it.bucket.machineId != _selectedMachineId) continue;
      out[it.bucket.partId] = (out[it.bucket.partId] ?? 0) + it.qty;
    }
    return out;
  }

  /// Buckets in the current plant filtered to the selected machine.
  /// Returns null while the provider is still loading or errored.
  List<DplProductionSummary>? _bucketsForSelectedMachine() {
    if (_selectedMachineId == null) return const [];
    final async = ref.read(
      dplProductionSummaryByPlantProvider(widget.plant.code),
    );
    final page = async.asData?.value.data;
    if (page == null) return null;
    return page.items
        .where((b) => b.machineId == _selectedMachineId)
        .toList(growable: false);
  }

  void _onMachineChanged(int? newId) {
    // The cart can span multiple machines for the same plant (one
    // slip can have items from machine A and machine B). So we don't
    // clear the cart on machine change — we just rebuild which
    // buckets the picker shows.
    setState(() {
      _selectedMachineId = newId;
      _serverError = null;
    });
  }

  void _onPartsAdded(List<PickedPart> picks) {
    if (picks.isEmpty) return;
    setState(() {
      for (final p in picks) {
        _cartItems.add(_CartItem(bucket: p.bucket, qty: p.qty));
      }
      _serverError = null;
    });
  }

  void _removeFromCart(int index) {
    setState(() {
      _cartItems.removeAt(index);
      _serverError = null;
    });
  }

  void _resetForm() {
    setState(() {
      _selectedMachineId = widget.plant.machines.length == 1
          ? widget.plant.machines.first.id
          : (widget.plant.machineIds.length == 1
              ? widget.plant.machineIds.first
              : null);
      _cartItems.clear();
      _vehicleCtrl.clear();
      _notesCtrl.clear();
      _serverError = null;
    });
  }

  Future<void> _submit() async {
    if (_cartItems.isEmpty) {
      setState(() => _serverError =
          'Add at least one item to the slip before sending.');
      return;
    }

    setState(() {
      _submitting = true;
      _serverError = null;
    });

    final vehicleNo = _vehicleCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final items = List<_CartItem>.from(_cartItems);

    final res = await ref.read(dplApiServiceProvider).createDispatchSlip(
      plantCode: widget.plant.code,
      items: [
        for (final it in items)
          DispatchSlipItemRequest(
            machineId: it.bucket.machineId,
            partId: it.bucket.partId,
            qty: it.qty,
          ),
      ],
      vehicleNo: vehicleNo.isEmpty ? null : vehicleNo,
      notes: notes.isEmpty ? null : notes,
    );

    if (!mounted) return;

    if (res.isError) {
      setState(() {
        _submitting = false;
        _serverError = res.error ?? 'Failed to create dispatch slip.';
      });
      return;
    }

    // Invalidate everything that displays slip / bucket / pipeline
    // data so the page reflects the new slip without a manual refresh.
    ref.invalidate(dplProductionSummaryProvider);
    ref.invalidate(dplDispatchSlipsProvider);
    ref.invalidate(dplBucketSlipCountsProvider);
    ref.invalidate(
      dplProductionSummaryByPlantProvider(widget.plant.code),
    );

    final slip = res.data;
    final fmt = NumberFormat.decimalPattern();
    final totalQty = items.fold<int>(0, (sum, it) => sum + it.qty);
    DplSnacks.success(
      context,
      'Slip ${slip?.slipNo ?? "created"} sent to QA · '
      '${items.length} item${items.length == 1 ? "" : "s"} · '
      '${fmt.format(totalQty)} NOS.',
    );
    _resetForm();
    setState(() => _submitting = false);
  }

  /// True when the plant has no machines assigned in the master data
  /// yet — transitional state during the migration-042 cutover where
  /// the customer hasn't confirmed the real machine mapping.
  bool get _hasNoMachines =>
      widget.plant.machines.isEmpty && widget.plant.machineIds.isEmpty;

  @override
  Widget build(BuildContext context) {
    final bucketsAsync = ref.watch(
      dplProductionSummaryByPlantProvider(widget.plant.code),
    );

    return Container(
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.palette.edge, width: 1.5),
        boxShadow: DplShadows.card,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left accent strip.
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: widget.palette.accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(15),
                  bottomLeft: Radius.circular(15),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PlantHeader(
                      plant: widget.plant,
                      palette: widget.palette,
                    ),
                    const SizedBox(height: 14),
                    _PlantStatsRow(
                      stats: widget.plant.stats,
                      palette: widget.palette,
                    ),
                    const SizedBox(height: 14),
                    const Divider(
                      height: 1,
                      color: DplColors.divider,
                    ),
                    const SizedBox(height: 12),
                    // Transitional state — the plant master moved to a
                    // DB table in migration 042, and until the customer-
                    // confirmed `plant → machines` mapping is INSERTed
                    // some plants legitimately have zero machines.
                    // Render a clear empty-state instead of an
                    // unusable form so the user knows why the
                    // dropdowns aren't there.
                    if (_hasNoMachines)
                      _NoMachinesAssignedState(palette: widget.palette)
                    else ...[
                      _MachineDropdown(
                        plant: widget.plant,
                        selectedId: _selectedMachineId,
                        onChanged: _onMachineChanged,
                      ),
                      const SizedBox(height: 10),
                      // Description field — tap to open the multi-
                      // select picker bottom sheet. Each row in the
                      // sheet has its own qty input so the user can
                      // queue several parts in one go.
                      _PartDropdown(
                        bucketsAsync: bucketsAsync,
                        selectedMachineId: _selectedMachineId,
                        buckets: _bucketsForSelectedMachine(),
                        alreadyInCartByPartId:
                            _cartCommitmentsForCurrentMachine(),
                        onPartsAdded: _onPartsAdded,
                      ),
                      // Cart of items added via the picker. Renders
                      // the running total + per-row delete icons.
                      if (_cartItems.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _CartList(
                          items: _cartItems,
                          palette: widget.palette,
                          onRemove: _removeFromCart,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _VehicleField(controller: _vehicleCtrl),
                      const SizedBox(height: 10),
                      _NotesField(controller: _notesCtrl),
                      if (_serverError != null) ...[
                        const SizedBox(height: 8),
                        _ErrorBox(message: _serverError!),
                      ],
                      const SizedBox(height: 14),
                      _Actions(
                        palette: widget.palette,
                        submitting: _submitting,
                        canSubmit:
                            !_submitting && _cartItems.isNotEmpty,
                        cartItemCount: _cartItems.length,
                        cartTotalQty: _cartTotalQty,
                        onReset: _resetForm,
                        onSubmit: _submit,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantHeader extends StatelessWidget {
  final DplPlant plant;
  final PlantCardPalette palette;

  const _PlantHeader({required this.plant, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: palette.edge),
          ),
          child: Icon(
            Icons.precision_manufacturing_outlined,
            size: 20,
            color: palette.accentDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plant.name,
                style: TextStyle(
                  color: palette.accentDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                plant.code,
                style: TextStyle(
                  color: palette.accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: palette.edge),
          ),
          child: Text(
            // Graceful empty state — until the customer-confirmed
            // plant→machine mapping lands the master row carries zero
            // machines. Read as "Setup pending" rather than the awkward
            // "0 machines" pill.
            plant.machineCount == 0
                ? 'Setup pending'
                : '${plant.machineCount} machine'
                    '${plant.machineCount == 1 ? "" : "s"}',
            style: TextStyle(
              color: palette.accentDark,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlantStatsRow extends StatelessWidget {
  final DplPlantStats stats;
  final PlantCardPalette palette;

  const _PlantStatsRow({required this.stats, required this.palette});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    // Production-side stats — always visible, always meaningful.
    final productionRow = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatTile(
          label: 'Actual',
          value: fmt.format(stats.totalActualQty),
          unit: 'NOS',
          accent: palette.accentDark,
        ),
        _StatTile(
          label: 'Plan',
          value: fmt.format(stats.totalPlanQty),
          unit: 'NOS',
        ),
        _StatTile(
          label: 'Available',
          value: fmt.format(stats.availableForDispatchQty),
          unit: 'NOS',
          accent: palette.accent,
          emphasised: true,
        ),
      ],
    );

    // Dispatch-side stats — only surface when the plant has any slip
    // activity, so plants with zero slips don't show three meaningless
    // zero tiles. The pending / approved / dispatched colour palette
    // mirrors the slip-status badges used on the QA / PDI inbox so the
    // semantic mapping stays consistent across the app.
    if (!stats.hasAnyDispatchActivity) return productionRow;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        productionRow,
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatTile(
              label: 'Pending',
              value: fmt.format(stats.pendingQty),
              unit: 'NOS',
              accent: DplColors.warning,
            ),
            _StatTile(
              label: 'Approved',
              value: fmt.format(stats.approvedQty),
              unit: 'NOS',
              accent: DplColors.info,
            ),
            _StatTile(
              label: 'Dispatched',
              value: fmt.format(stats.dispatchedQty),
              unit: 'NOS',
              accent: DplColors.success,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? accent;
  final bool emphasised;

  const _StatTile({
    required this.label,
    required this.value,
    this.unit,
    this.accent,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: emphasised ? DplColors.primaryTint : DplColors.pageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: emphasised
              ? (accent ?? DplColors.primary).withValues(alpha: 0.25)
              : DplColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accent ?? DplColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: TextStyle(
                    color: accent ?? DplColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ],
          ),
          Text(
            label,
            style: const TextStyle(
              color: DplColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// Machine dropdown — name + code on the top line, plus a small stats
/// line below showing per-machine `actual / in-pipeline / pending` qty
/// so the user can pick the machine that has the production they want
/// to dispatch without having to drill in first.
///
/// Stats are derived from the per-plant production-summary buckets:
///   * actual:      SUM(bucket.totalActualQty)            across the machine's buckets
///   * in-pipeline: SUM(bucket.totalActualQty − available) across the machine's buckets
///   * pending:     SUM(bucket.totalPlanQty − bucket.totalActualQty)
///
/// Watches the same `dplProductionSummaryByPlantProvider` the part
/// dropdown reads, so the data is shared (one fetch per plant).
class _MachineDropdown extends ConsumerWidget {
  final DplPlant plant;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _MachineDropdown({
    required this.plant,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bucketsAsync = ref.watch(
      dplProductionSummaryByPlantProvider(plant.code),
    );
    final statsByMachine = _aggregateStats(
      bucketsAsync.asData?.value.data?.items,
    );

    // Build a normalised list of (id, label, code) entries so both
    // `items` and `selectedItemBuilder` walk the same data in the same
    // order. Prefer the enriched `machines[]` block; fall back to
    // `machineIds` so the dropdown never goes empty if master data is
    // missing.
    final List<({int id, String label, String code})> entries;
    if (plant.machines.isNotEmpty) {
      entries = [
        for (final m in plant.machines)
          (id: m.id, label: m.label, code: m.code),
      ];
    } else {
      entries = [
        for (final id in plant.machineIds)
          (id: id, label: 'Machine #$id', code: ''),
      ];
    }

    return DropdownButtonFormField<int>(
      initialValue: selectedId,
      onChanged: onChanged,
      isExpanded: true,
      // null lets the dropdown items size to their intrinsic content
      // — needed because each entry is two lines tall.
      itemHeight: null,
      items: [
        for (final e in entries)
          DropdownMenuItem<int>(
            value: e.id,
            child: _MachineDropdownEntry(
              label: e.label,
              code: e.code,
              stats: statsByMachine[e.id],
            ),
          ),
      ],
      // When an item is selected, the field area should only show the
      // top-line summary (name + code) — the stats line is dropdown-
      // menu-only context and would visually clutter the input field.
      selectedItemBuilder: (context) => [
        for (final e in entries)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _MachineRow(label: e.label, code: e.code),
          ),
      ],
      decoration: InputDecoration(
        labelText: 'Machine',
        prefixIcon: const Icon(Icons.precision_manufacturing_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v == null ? 'Select a machine.' : null,
    );
  }

  /// Bucket items grouped by `machineId` → `_MachineStats`.
  /// `null` when the per-plant production-summary fetch hasn't landed
  /// yet, so the dropdown can fall back to showing the name+code only.
  Map<int, _MachineStats> _aggregateStats(
    List<DplProductionSummary>? buckets,
  ) {
    if (buckets == null) return const {};
    final map = <int, _MachineStats>{};
    for (final b in buckets) {
      final existing = map[b.machineId] ?? const _MachineStats();
      map[b.machineId] = existing.add(b);
    }
    return map;
  }
}

/// Per-machine roll-up over the bucket list.
class _MachineStats {
  final int actualQty;
  final int planQty;
  final int availableQty;

  const _MachineStats({
    this.actualQty = 0,
    this.planQty = 0,
    this.availableQty = 0,
  });

  /// `actual − available` = qty committed to non-rejected slips
  /// (pending_qa + pending_pdi + approved + dispatched). Closest
  /// available approximation of "in pipeline" the bucket data alone
  /// can give us without a separate slip-list fetch — and the right
  /// signal for "how much of this machine's stock is locked up".
  int get inPipelineQty {
    final v = actualQty - availableQty;
    return v < 0 ? 0 : v;
  }

  /// `plan − actual` = qty still to produce.
  int get pendingQty {
    final v = planQty - actualQty;
    return v < 0 ? 0 : v;
  }

  bool get isEmpty => actualQty == 0 && planQty == 0 && availableQty == 0;

  _MachineStats add(DplProductionSummary b) {
    return _MachineStats(
      actualQty: actualQty + b.totalActualQty,
      planQty: planQty + b.totalPlanQty,
      availableQty: availableQty + b.availableForDispatchQty,
    );
  }
}

/// One entry in the open dropdown menu — two lines tall:
///   line 1: machine name + code (the existing `_MachineRow`)
///   line 2: small stats string, dimmed grey
class _MachineDropdownEntry extends StatelessWidget {
  final String label;
  final String code;
  final _MachineStats? stats;

  const _MachineDropdownEntry({
    required this.label,
    required this.code,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final s = stats;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MachineRow(label: label, code: code),
        if (s != null) ...[
          const SizedBox(height: 2),
          Text(
            s.isEmpty
                ? 'No production yet'
                : '${fmt.format(s.actualQty)} actual'
                    '  ·  ${fmt.format(s.inPipelineQty)} in pipeline',
            style: const TextStyle(
              color: DplColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _MachineRow extends StatelessWidget {
  final String label;
  final String code;
  const _MachineRow({required this.label, required this.code});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (code.isNotEmpty && code != label) ...[
          const SizedBox(width: 6),
          Text(
            '· $code',
            style: const TextStyle(
              color: DplColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// Description picker for the chosen machine. Tapping the field opens
/// a modal bottom sheet (`_PartPickerSheet`) where the user can enter
/// qty for any number of parts at once — pick a single part, or
/// spread one dispatch across multiple parts when no single bucket
/// has enough stock.
///
/// We swapped off Flutter's `Autocomplete<T>` because its overlay
/// positioning doesn't play well with sliver-based scroll views on
/// web. A modal sheet sidesteps all of that.
class _PartDropdown extends StatelessWidget {
  final AsyncValue<dynamic> bucketsAsync;
  final int? selectedMachineId;
  final List<DplProductionSummary>? buckets;

  /// Qty already committed in the parent cart, keyed by `partId`.
  /// Passed through to the picker so each row's "available" reflects
  /// what's still bookable after subtracting cart commitments.
  final Map<int, int> alreadyInCartByPartId;

  /// Called with the picked rows when the user hits "Add to slip" in
  /// the picker. Empty list / null when the user cancels.
  final void Function(List<PickedPart> picks) onPartsAdded;

  const _PartDropdown({
    required this.bucketsAsync,
    required this.selectedMachineId,
    required this.buckets,
    required this.alreadyInCartByPartId,
    required this.onPartsAdded,
  });

  @override
  Widget build(BuildContext context) {
    final hint = _hintForState();
    final enabled = hint == null;

    return _PartPickerField(
      label: 'Description',
      placeholder: enabled ? 'Tap to pick parts' : hint,
      enabled: enabled,
      onTap: enabled ? () => _openPicker(context) : null,
    );
  }

  String? _hintForState() {
    if (selectedMachineId == null) return 'Select a machine first';
    if (buckets == null) {
      if (bucketsAsync is AsyncError) return 'Failed to load parts';
      return 'Loading parts…';
    }
    if (buckets!.isEmpty) return 'No parts with stock for this machine';
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<List<PickedPart>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PartPickerSheet(
        buckets: buckets!,
        alreadyInCartByPartId: alreadyInCartByPartId,
      ),
    );
    if (picked != null && picked.isNotEmpty) onPartsAdded(picked);
  }
}

/// The on-screen description "field" — visually mimics a real input
/// so it lines up with the other form fields, but it's actually a
/// tap target that opens the picker bottom sheet.
class _PartPickerField extends StatelessWidget {
  final String label;
  final String placeholder;
  final bool enabled;
  final VoidCallback? onTap;

  const _PartPickerField({
    required this.label,
    required this.placeholder,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        isEmpty: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: placeholder,
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: Icon(
            Icons.arrow_drop_down_rounded,
            color: enabled
                ? DplColors.textSecondary
                : DplColors.textTertiary,
          ),
          enabled: enabled,
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: null,
      ),
    );
  }
}

/// One picked row returned from the bottom-sheet picker. Caller (the
/// plant card) appends each of these to its cart.
class PickedPart {
  final DplProductionSummary bucket;
  final int qty;
  const PickedPart({required this.bucket, required this.qty});
}

/// Multi-select bottom-sheet part picker. Each row has its own qty
/// input so the user can pick several parts in a single open — type
/// qty into row 1, type qty into row 5, hit "Add to slip", both rows
/// land in the cart at once.
///
///   * Search field at top filters all rows by name / P/N / material code
///   * Each row shows live "X NOS available (Y in cart)" with cart
///     commitments subtracted so the user can't over-allocate one
///     bucket across multiple cart entries
///   * Per-row validator caps at remaining-available; submit button at
///     the bottom is disabled until at least one row has a valid qty
///   * Sticky footer with running total + Cancel + "Add N items · X NOS"
class _PartPickerSheet extends StatefulWidget {
  final List<DplProductionSummary> buckets;

  /// Qty already in the parent cart per `bucket.partId`, used to
  /// reduce each row's display + cap so the user can't double-allocate.
  final Map<int, int> alreadyInCartByPartId;

  const _PartPickerSheet({
    required this.buckets,
    required this.alreadyInCartByPartId,
  });

  @override
  State<_PartPickerSheet> createState() => _PartPickerSheetState();
}

class _PartPickerSheetState extends State<_PartPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  // Per-row qty controllers, keyed by `bucket.id` so collisions can't
  // happen even if the buckets list spans multiple machines.
  final Map<int, TextEditingController> _qtyCtrls = {};
  String _query = '';

  @override
  void initState() {
    super.initState();
    for (final b in widget.buckets) {
      final ctrl = TextEditingController()..addListener(_onAnyQtyChanged);
      _qtyCtrls[b.id] = ctrl;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    for (final c in _qtyCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _onAnyQtyChanged() {
    // Rebuild so the footer's running total + button enablement
    // update on every keystroke.
    if (mounted) setState(() {});
  }

  List<DplProductionSummary> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.buckets;
    return widget.buckets.where((b) {
      return b.partName.toLowerCase().contains(q) ||
          b.description.toLowerCase().contains(q) ||
          b.customerPartNo.toLowerCase().contains(q) ||
          b.materialCode.toLowerCase().contains(q) ||
          b.substratePartNo.toLowerCase().contains(q);
    }).toList(growable: false);
  }

  int _availableForRow(DplProductionSummary b) {
    final committed = widget.alreadyInCartByPartId[b.partId] ?? 0;
    final remaining = b.availableForDispatchQty - committed;
    return remaining < 0 ? 0 : remaining;
  }

  /// Walks every row controller and returns the rows where the qty is
  /// a valid positive integer that doesn't exceed the per-row cap.
  List<PickedPart> _validPicks() {
    final out = <PickedPart>[];
    for (final b in widget.buckets) {
      final raw = _qtyCtrls[b.id]?.text.trim() ?? '';
      if (raw.isEmpty) continue;
      final n = int.tryParse(raw);
      if (n == null || n <= 0) continue;
      if (n > _availableForRow(b)) continue;
      out.add(PickedPart(bucket: b, qty: n));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final visible = _visible;
    final mediaQuery = MediaQuery.of(context);
    final picks = _validPicks();
    final canAdd = picks.isNotEmpty;
    final totalQty = picks.fold<int>(0, (s, p) => s + p.qty);
    final maxSheetHeight = mediaQuery.size.height * 0.85;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Container(
          decoration: const BoxDecoration(
            color: DplColors.cardBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: DplShadows.sheet,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: DplColors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text('Pick parts', style: DplText.h3()),
                      const SizedBox(width: 8),
                      Text(
                        '— enter qty in each part you want',
                        style: const TextStyle(
                          color: DplColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    textInputAction: TextInputAction.search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText:
                          'Search by name, customer P/N, material code…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const Divider(height: 1, color: DplColors.divider),
                Expanded(
                  child: visible.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Center(
                            child: Text(
                              'No parts match "$_query".',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: DplColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: DplColors.divider,
                          ),
                          itemBuilder: (_, i) {
                            final b = visible[i];
                            return _PickerRow(
                              bucket: b,
                              controller: _qtyCtrls[b.id]!,
                              availableForRow: _availableForRow(b),
                              alreadyInCart:
                                  widget.alreadyInCartByPartId[b.partId] ?? 0,
                            );
                          },
                        ),
                ),
                // Footer — always visible, sticky.
                const Divider(height: 1, color: DplColors.divider),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: canAdd
                              ? () => Navigator.of(context).pop(picks)
                              : null,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(canAdd
                              ? 'Add ${picks.length} '
                                  'item${picks.length == 1 ? "" : "s"} · '
                                  '${fmt.format(totalQty)} NOS'
                              : 'Add to slip'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row inside the multi-select picker. Renders part info on the
/// left, qty input on the right. Disabled (greyed) when there's
/// nothing left to allocate (`availableForRow == 0`).
class _PickerRow extends StatelessWidget {
  final DplProductionSummary bucket;
  final TextEditingController controller;
  final int availableForRow;
  final int alreadyInCart;

  const _PickerRow({
    required this.bucket,
    required this.controller,
    required this.availableForRow,
    required this.alreadyInCart,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final hasStock = availableForRow > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bucket.partLabel,
                  style: TextStyle(
                    color: hasStock
                        ? DplColors.textPrimary
                        : DplColors.textTertiary,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (bucket.customerPartNo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    bucket.customerPartNo,
                    style: const TextStyle(
                      color: DplColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  alreadyInCart > 0
                      ? '${fmt.format(availableForRow)} NOS available'
                          ' · ${fmt.format(alreadyInCart)} in cart'
                      : '${fmt.format(availableForRow)} NOS available',
                  style: TextStyle(
                    color: hasStock
                        ? DplColors.primaryDark
                        : DplColors.textTertiary,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 104,
            child: TextField(
              controller: controller,
              enabled: hasStock,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(7),
              ],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: 'Qty',
                hintText: hasStock ? '0' : '—',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}




/// Cart of items the user has already added to the in-progress slip.
/// Renders as a soft bordered block with one row per item and an
/// inline delete button. Header carries the running totals so the user
/// always sees "how much have I queued so far".
class _CartList extends StatelessWidget {
  final List<_CartItem> items;
  final PlantCardPalette palette;
  final void Function(int index) onRemove;

  const _CartList({
    required this.items,
    required this.palette,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final totalQty = items.fold<int>(0, (s, it) => s + it.qty);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row — title + running totals.
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(
              children: [
                Icon(
                  Icons.list_alt_rounded,
                  size: 16,
                  color: palette.accentDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'In this slip',
                    style: TextStyle(
                      color: palette.accentDark,
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                Text(
                  '${items.length} item'
                  '${items.length == 1 ? "" : "s"} · '
                  '${fmt.format(totalQty)} NOS',
                  style: TextStyle(
                    color: palette.accentDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.edge),
          // Each cart item.
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: palette.edge),
            _CartRow(
              item: items[i],
              palette: palette,
              onRemove: () => onRemove(i),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartRow extends StatelessWidget {
  final _CartItem item;
  final PlantCardPalette palette;
  final VoidCallback onRemove;

  const _CartRow({
    required this.item,
    required this.palette,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final bucket = item.bucket;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bucket.partLabel,
                  style: const TextStyle(
                    color: DplColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12.5,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (bucket.customerPartNo.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    bucket.customerPartNo,
                    style: const TextStyle(
                      color: DplColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      letterSpacing: 0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  '${bucket.machineLabel} · ${fmt.format(item.qty)} NOS',
                  style: TextStyle(
                    color: palette.accentDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: DplColors.error,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final PlantCardPalette palette;
  final bool submitting;
  final bool canSubmit;

  /// Number of items that would be sent if the user clicked submit
  /// right now (cart rows + the in-progress row if it's valid).
  /// Drives the button's secondary "X items · N NOS" label.
  final int cartItemCount;
  final int cartTotalQty;

  final VoidCallback onReset;
  final VoidCallback onSubmit;

  const _Actions({
    required this.palette,
    required this.submitting,
    required this.canSubmit,
    required this.cartItemCount,
    required this.cartTotalQty,
    required this.onReset,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    String label;
    if (submitting) {
      label = 'Sending…';
    } else if (cartItemCount == 0) {
      label = 'Send to QA';
    } else if (cartItemCount == 1) {
      label = 'Send to QA · ${fmt.format(cartTotalQty)} NOS';
    } else {
      label = 'Send to QA · $cartItemCount items · '
          '${fmt.format(cartTotalQty)} NOS';
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: submitting ? null : onReset,
            child: const Text('Reset'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: canSubmit ? onSubmit : null,
            icon: submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: palette.accentDark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: DplColors.neutralBg,
              disabledForegroundColor: DplColors.textTertiary,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Optional vehicle-number input. Backend trims + uppercases server
/// side; we also force uppercase on the FE so what the user sees
/// matches what gets persisted. 32-char cap matches the
/// `vehicle_no VARCHAR(32)` column.
class _VehicleField extends StatelessWidget {
  final TextEditingController controller;
  const _VehicleField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: [
        LengthLimitingTextInputFormatter(32),
        _UpperCaseFormatter(),
      ],
      decoration: InputDecoration(
        labelText: 'Vehicle no (optional)',
        hintText: 'e.g. GJ-01-AB-1234',
        prefixIcon: const Icon(Icons.local_shipping_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Optional free-text notes — customer ref, special instructions, etc.
class _NotesField extends StatelessWidget {
  final TextEditingController controller;
  const _NotesField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 2,
      maxLength: 240,
      decoration: InputDecoration(
        labelText: 'Notes (optional)',
        hintText: 'Customer ref, special instructions, etc.',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// Inline red error block — shown above the action row when the
/// server rejects a submit, or when local validation catches
/// something before the request goes out.
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DplColors.errorBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DplColors.error),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline,
              size: 18, color: DplColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: DplColors.error,
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly empty-state shown in place of the slip-request form when
/// a plant has zero machines assigned in the master data. Currently
/// transitional: migration 042 moved the plant master to a DB table
/// and the customer-confirmed plant-to-machine INSERTs are pending. As
/// soon as backend runs them, this widget disappears and the form
/// renders normally.
class _NoMachinesAssignedState extends StatelessWidget {
  final PlantCardPalette palette;
  const _NoMachinesAssignedState({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.edge),
                ),
                child: Icon(
                  Icons.build_outlined,
                  size: 18,
                  color: palette.accentDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No machines assigned yet',
                  style: TextStyle(
                    color: palette.accentDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Once the plant's machine mapping is configured, the slip "
            'request form will appear here. Production stats above will '
            'populate as soon as the assigned machines start producing.',
            style: TextStyle(
              color: palette.accentDark.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Force-uppercase TextInputFormatter for the vehicle-number field.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    return TextEditingValue(
      text: upper,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
