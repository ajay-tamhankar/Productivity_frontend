import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/dpl_theme.dart';
import '../../core/dpl_api_service.dart';
import '../../core/dpl_organization_provider.dart';
import '../../core/widgets/dpl_snack.dart';
import '../../manager/widgets/error_retry.dart';
import '../../models/dpl_dispatch_slip.dart';
import '../../models/dpl_dispatch_trip.dart';
import '../../models/dpl_production_summary.dart';
import '../providers/dispatch_slips_provider.dart';
import '../providers/dispatch_trips_provider.dart';
import '../providers/production_summary_provider.dart';
import '../services/dispatch_slip_pdf.dart';

/// Top-of-landing section that lists today's open + partial trips
/// the manager has submitted. Each trip card lets the dispatcher
/// multi-select plans + optionally edit qty (decrease only, with a
/// variance note), then "Send for PDI" cuts a slip from the chosen
/// plans via `POST /dispatch/slips` with `trip_id` + `trip_plan_ids`.
///
/// This is the *new* slip-creation entry point. The legacy per-plant
/// manual machine-picker form (in `PlantCard`) remains visible during
/// transition — Phase 3 will gate it behind a feature flag.
class OpenTripsSection extends ConsumerWidget {
  const OpenTripsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(dplOpenTripsProvider(null));

    return tripsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: DplErrorRetry(
          message: e.toString(),
          onRetry: () => ref.invalidate(dplOpenTripsProvider(null)),
        ),
      ),
      data: (res) {
        if (res.isError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: DplErrorRetry(
              message: res.error ?? 'Failed to load open trips.',
              onRetry: () => ref.invalidate(dplOpenTripsProvider(null)),
            ),
          );
        }
        final trips = res.data?.trips ?? const <DplTrip>[];
        if (trips.isEmpty) return const _NoOpenTrips();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      size: 16, color: DplColors.primaryDark),
                  const SizedBox(width: 6),
                  Text(
                    'OPEN TRIPS (${trips.length})',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: DplColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            for (final t in trips)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _OpenTripCard(trip: t),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Divider(color: DplColors.divider, height: 1),
            ),
          ],
        );
      },
    );
  }
}

class _NoOpenTrips extends StatelessWidget {
  const _NoOpenTrips();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: DplColors.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: DplColors.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_shipping_outlined,
                size: 18, color: DplColors.textSecondary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'No open trips. Once the manager submits a Plan Trip, '
                'it will appear here ready to dispatch.',
                style: TextStyle(
                  color: DplColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────── Trip card ──────────────

class _OpenTripCard extends ConsumerStatefulWidget {
  final DplTrip trip;
  const _OpenTripCard({required this.trip});

  @override
  ConsumerState<_OpenTripCard> createState() => _OpenTripCardState();
}

class _OpenTripCardState extends ConsumerState<_OpenTripCard> {
  /// Plan ids the dispatcher has ticked. Only `open` plans are
  /// tickable — the rest already have a slip and are displayed
  /// read-only with the slip reference.
  final Set<int> _selected = {};

  /// Working qty overrides (kept local until the dispatcher hits
  /// Send for PDI). PATCH is fired during Send if any override differs
  /// from the plan's qty.
  final Map<int, int> _qtyOverride = {};

  /// Notes captured per plan when qty is decreased — required by the
  /// backend's `PATCH /dispatch/trips/:id/plans/:planId` rule.
  final Map<int, String> _varianceNote = {};

  final _vehicleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  List<DplTripPlan> get _openPlans => widget.trip.plans
      .where((p) => DplTripPlanStatus.isBookable(p.status))
      .toList(growable: false);

  int _qtyFor(DplTripPlan p) => _qtyOverride[p.id] ?? p.qty;

  bool _isSelected(DplTripPlan p) => _selected.contains(p.id);

  /// `(machine_id, part_id) → available_for_dispatch_qty` for the
  /// trip's plant. Returns `null` while the production-summary fetch
  /// is in flight or errored — caller treats that as "no cap" and
  /// falls back to the original UX (we don't block selection just
  /// because the lookup hasn't loaded yet).
  Map<String, int>? _buildAvailableMap(AsyncValue<dynamic> async) {
    final res = async.asData?.value;
    if (res == null || res.isError) return null;
    final page = res.data;
    if (page == null) return null;
    final items = (page as DplProductionSummaryPage).items;
    return {
      for (final s in items) '${s.machineId}:${s.partId}': s.availableForDispatchQty,
    };
  }

  /// Look up the available bucket qty for a single plan. `null` means
  /// "no cap" (production-summary hasn't loaded). `0` means "out of
  /// stock — backend will reject".
  int? _availableFor(DplTripPlan p, Map<String, int>? availableByKey) {
    if (availableByKey == null) return null;
    return availableByKey['${p.machineId}:${p.partId}'] ?? 0;
  }

  /// Builds the checkbox toggle handler. Returns `null` only when the
  /// plan's *business* status disqualifies it (already slipped /
  /// dispatched / cancelled). Stock constraints are handled separately
  /// inside `_PlanRow` so the row can still render the "Out of stock"
  /// hint instead of falling through to the raw-status label.
  VoidCallback? _toggleHandlerFor(DplTripPlan p) {
    if (!DplTripPlanStatus.isBookable(p.status)) return null;
    return () {
      setState(() {
        if (!_selected.add(p.id)) _selected.remove(p.id);
      });
    };
  }

  /// Plans on this trip that are no longer open — already converted
  /// to a slip or fully dispatched. We hide them from the actionable
  /// list and summarise them at the top of the trip card.
  Iterable<DplTripPlan> _priorSlippedPlans(List<DplTripPlan> plans) =>
      plans.where((p) => !DplTripPlanStatus.isBookable(p.status));

  int _priorSlippedCount(List<DplTripPlan> plans) =>
      _priorSlippedPlans(plans).length;

  int _priorSlippedQty(List<DplTripPlan> plans) =>
      _priorSlippedPlans(plans).fold<int>(0, (s, p) => s + p.qty);

  /// Distinct slip ids on this trip's already-slipped plans — surfaces
  /// the "Slip #N" deep-link chip on the summary so the dispatcher can
  /// cross-reference what was cut.
  List<int> _priorSlipIds(List<DplTripPlan> plans) {
    final ids = <int>{};
    for (final p in _priorSlippedPlans(plans)) {
      if (p.slipId != null) ids.add(p.slipId!);
    }
    return ids.toList()..sort();
  }

  int get _selectedTotalQty {
    var sum = 0;
    for (final p in _openPlans) {
      if (_isSelected(p)) sum += _qtyFor(p);
    }
    return sum;
  }

  /// Vehicle number is now mandatory before a slip can be cut — every
  /// PDI'd slip needs a truck plate on the audit trail. The button is
  /// disabled while this returns true; we also re-check inside
  /// `_onSend` as a belt-and-braces guard against a stale render.
  bool get _vehicleMissing => _vehicleCtrl.text.trim().isEmpty;

  Future<void> _onSend() async {
    if (_selected.isEmpty) {
      DplSnacks.error(context, 'Tick at least one plan to send for PDI.');
      return;
    }
    if (_vehicleMissing) {
      DplSnacks.error(
        context,
        'Vehicle no is required before sending for PDI.',
      );
      return;
    }

    // Run PATCHes for any plan whose qty was edited before cutting
    // the slip. We do them sequentially so the variance log on the
    // backend reads naturally in the audit trail.
    final api = ref.read(dplApiServiceProvider);
    setState(() => _submitting = true);

    for (final p in _openPlans) {
      if (!_isSelected(p)) continue;
      final newQty = _qtyFor(p);
      if (newQty == p.qty) continue;
      final note = _varianceNote[p.id]?.trim() ?? '';
      if (note.isEmpty) {
        if (!mounted) return;
        setState(() => _submitting = false);
        DplSnacks.error(
          context,
          'Plan ${p.description}: add a variance note before reducing qty.',
        );
        return;
      }
      final patchRes = await api.patchTripPlanQty(
        widget.trip.id,
        p.id,
        qty: newQty,
        varianceNote: note,
      );
      if (!mounted) return;
      if (patchRes.isError) {
        setState(() => _submitting = false);
        DplSnacks.error(
          context,
          'Plan ${p.description} qty update failed: '
          '${patchRes.error ?? "unknown error"}',
        );
        return;
      }
    }

    // ONE slip per plan — the customer-facing manifest stays atomic
    // (one part per slip). We POST sequentially per ticked plan; on
    // a mid-loop failure we stop, surface what got created vs what
    // didn't, and keep the still-pending plans selected so the user
    // can retry just those.
    //
    // We collect the FULL slip objects (not just slipNos) so that
    // once the loop succeeds we can render them into a single
    // multi-page PDF and email the whole trip in one shot — same
    // logic the Trip Slips screen uses. Stops the "5 plans = 5
    // emails" problem at the source.
    final pendingIds = _selected.toList(growable: false);
    final createdSlips = <DplDispatchSlip>[];
    String? failedError;
    int failedAtIndex = -1;

    for (var i = 0; i < pendingIds.length; i++) {
      final planId = pendingIds[i];
      final res = await api.createDispatchSlipFromTrip(
        tripId: widget.trip.id,
        tripPlanIds: [planId],
        vehicleNo: _vehicleCtrl.text,
        notes: _notesCtrl.text,
      );
      if (!mounted) return;
      if (res.isError) {
        failedError = res.error ?? 'unknown error';
        failedAtIndex = i;
        break;
      }
      final created = res.data;
      if (created != null) createdSlips.add(created);
      // Drop the just-slipped plan from the selection so any retry
      // only re-attempts the remaining ones.
      setState(() => _selected.remove(planId));
    }

    // Refresh the upstream caches so the trip list, slip inbox and
    // production-summary buckets all reflect the new slips without a
    // manual refresh — fire even on partial failure so the visible
    // ones land before the error snack.
    ref.invalidate(dplOpenTripsProvider(null));
    ref.invalidate(dplOpenTripsProvider(widget.trip.plantCode));
    ref.invalidate(dplDispatchSlipsProvider);
    ref.invalidate(dplProductionSummaryProvider);
    ref.invalidate(
      dplProductionSummaryByPlantProvider(widget.trip.plantCode),
    );

    if (failedError != null) {
      setState(() => _submitting = false);
      // INSUFFICIENT_QTY is the most common cause once a trip is
      // built — surface it with bucket-level guidance so the
      // dispatcher knows to refresh + reduce. Everything else falls
      // through to the raw backend error.
      final isStockError = failedError.contains('available for') ||
          failedError.toUpperCase().contains('INSUFFICIENT');
      final remaining = pendingIds.length - failedAtIndex;
      final ok = createdSlips.length;
      DplSnacks.error(
        context,
        isStockError
            ? 'Stopped after $ok of ${pendingIds.length}: not enough '
                'produced stock for plan ${failedAtIndex + 1}. '
                'Reduce qty and retry the remaining $remaining.'
            : 'Stopped after $ok of ${pendingIds.length}: $failedError',
      );
      return;
    }

    final n = createdSlips.length;
    final slipNos = [for (final s in createdSlips) s.slipNo];

    setState(() {
      _submitting = false;
      _qtyOverride.clear();
      _varianceNote.clear();
      _vehicleCtrl.clear();
      _notesCtrl.clear();
    });

    DplSnacks.success(
      context,
      n == 1
          ? 'Slip ${slipNos.first} created from '
              'Trip ${widget.trip.tripNumber}. Now in PDI queue.'
          : '$n slips created from Trip ${widget.trip.tripNumber}. '
              'Now in PDI queue.',
    );

    // Auto-email the freshly-cut slip stack as a single PDF. Done as
    // a follow-up snack so the "created" success above remains the
    // hero confirmation — the email outcome is informational.
    if (createdSlips.isNotEmpty) {
      await _emailCreatedSlipsAsBatch(createdSlips);
    }
  }

  /// Renders the just-created slips into ONE multi-page PDF (one A4
  /// page per slip via [DispatchSlipPdfBuilder.buildBatch]) and POSTs
  /// it once to `POST /dispatch/slips/<first id>/email`. Result is a
  /// single email with a single PDF attachment regardless of how many
  /// slips were cut — mirrors the Trip Slips screen "Email all"
  /// behavior so the recipient inbox stays clean.
  ///
  /// Endpoint quirk: the email endpoint is keyed by slip id (no
  /// trip-level email endpoint), so the server-generated subject +
  /// canonical filename reference the first slip's metadata. We set
  /// `subject_suffix=Trip #N (M slips)` to mark it as a batch.
  Future<void> _emailCreatedSlipsAsBatch(
    List<DplDispatchSlip> slips,
  ) async {
    final api = ref.read(dplApiServiceProvider);
    final orgLabel = ref.read(dplActiveOrganizationProvider)?.displayLabel;
    final anchor = slips.first;
    final tripNumber = widget.trip.tripNumber;
    final plantCode = widget.trip.plantCode;
    final suffix = slips.length == 1
        ? 'Trip #$tripNumber'
        : 'Trip #$tripNumber (${slips.length} slips)';
    final filename = slips.length == 1
        ? '${anchor.slipNo}.pdf'
        : 'Trip-$tripNumber-'
            '${plantCode.isEmpty ? "slips" : plantCode}.pdf';

    Uint8List bytes;
    try {
      bytes = await DispatchSlipPdfBuilder.buildBatch(
        slips,
        organizationLabel: orgLabel,
      );
    } catch (e) {
      if (!mounted) return;
      DplSnacks.error(context, 'Slip PDF render failed for email: $e');
      return;
    }

    final res = await api.sendDispatchSlipEmail(
      anchor.id,
      pdfBytes: bytes,
      filename: filename,
      subjectSuffix: suffix,
    );

    if (!mounted) return;

    if (res.isError) {
      DplSnacks.error(
        context,
        'Slip${slips.length == 1 ? "" : "s"} created but email failed: '
        '${res.error ?? "unknown error"}',
      );
      return;
    }
    final data = res.data;
    if (data == null) return;
    if (data.sent) {
      final toLabel =
          data.to.isNotEmpty ? data.to.first : 'Dispatch';
      DplSnacks.success(
        context,
        slips.length == 1
            ? 'Slip emailed to $toLabel.'
            : '${slips.length} slips emailed to $toLabel in one PDF.',
      );
    } else if (data.skipped) {
      DplSnacks.warning(
        context,
        'Email skipped — SMTP is not configured on this deploy.',
      );
    } else {
      DplSnacks.error(
        context,
        'Email not sent: ${data.reason ?? "unknown reason"}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final t = widget.trip;
    final openPlans = _openPlans;

    // Production-summary lookup — kept around so the per-row hint
    // ("Out of stock", "N NOS available") still renders as
    // informational context. The hard gate (disabling tick / qty
    // input / Send when stock is short) was lifted on operator
    // request: the backend may still reject with INSUFFICIENT_QTY,
    // and that error surfaces in the snack — but the FE no longer
    // pre-blocks the attempt.
    final summaryAsync =
        ref.watch(dplProductionSummaryByPlantProvider(t.plantCode));
    final Map<String, int>? availableByKey =
        _buildAvailableMap(summaryAsync);

    final canSend = !_submitting &&
        _selected.isNotEmpty &&
        !_vehicleMissing;

    return Container(
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TripHeader(trip: t),
          // Compact summary of plans already slipped earlier from this
          // trip. We hide those rows from the actionable list to keep
          // the card focused on what the dispatcher can still ship,
          // but surface the count + total NOS so it's obvious that a
          // slip was successfully cut and the trip's still here only
          // because other plans remain open.
          if (_priorSlippedCount(t.plans) > 0)
            _PriorSlipsSummary(
              slippedCount: _priorSlippedCount(t.plans),
              slippedQty: _priorSlippedQty(t.plans),
              slipIds: _priorSlipIds(t.plans),
            ),
          for (final plan in openPlans) ...[
            const Divider(height: 1, color: DplColors.divider),
            _PlanRow(
              plan: plan,
              isSelected: _isSelected(plan),
              qty: _qtyFor(plan),
              varianceNote: _varianceNote[plan.id] ?? '',
              available: _availableFor(plan, availableByKey),
              onToggle: _toggleHandlerFor(plan),
              onQtyChanged: (v) {
                setState(() {
                  if (v == plan.qty) {
                    _qtyOverride.remove(plan.id);
                  } else {
                    _qtyOverride[plan.id] = v;
                  }
                });
              },
              onVarianceChanged: (v) {
                setState(() => _varianceNote[plan.id] = v);
              },
            ),
          ],
          // Vehicle + notes — apply to whichever plans are checked.
          if (openPlans.isNotEmpty) ...[
            const Divider(height: 1, color: DplColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Column(
                children: [
                  _OptionalText(
                    controller: _vehicleCtrl,
                    icon: Icons.local_shipping_outlined,
                    hint: 'Vehicle no *',
                    maxLength: 32,
                    required: true,
                    showError: _vehicleMissing && _selected.isNotEmpty,
                    errorText: 'Vehicle no is required',
                    // Re-evaluate the Send button + footer copy on
                    // every keystroke so the gate visibly unlocks
                    // as soon as a plate is typed.
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  _OptionalText(
                    controller: _notesCtrl,
                    icon: Icons.notes_outlined,
                    hint: 'Notes (optional)',
                    maxLength: 240,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: DplColors.divider),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _selected.isEmpty
                          ? 'Tick plans to include'
                          : (_vehicleMissing
                              ? 'Enter vehicle no to send'
                              : '${_selected.length} plan'
                                  '${_selected.length == 1 ? "" : "s"} · '
                                  '${fmt.format(_selectedTotalQty)} NOS'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: _selected.isEmpty
                            ? DplColors.textSecondary
                            : (_vehicleMissing
                                ? DplColors.warning
                                : DplColors.primaryDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: canSend ? _onSend : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_submitting ? 'Sending…' : 'Send for PDI'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact "X plans already slipped" summary rendered between the
/// purple trip header and the actionable plan rows. Only mounts when
/// at least one plan on the trip has been converted to a slip. The
/// slip-id chips give the dispatcher a quick cross-reference without
/// leaving the dashboard.
class _PriorSlipsSummary extends StatelessWidget {
  final int slippedCount;
  final int slippedQty;
  final List<int> slipIds;
  const _PriorSlipsSummary({
    required this.slippedCount,
    required this.slippedQty,
    required this.slipIds,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    return Container(
      width: double.infinity,
      color: DplColors.successBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 14, color: DplColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$slippedCount plan${slippedCount == 1 ? "" : "s"} already '
              'slipped · ${fmt.format(slippedQty)} NOS',
              style: const TextStyle(
                color: DplColors.success,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
          ),
          if (slipIds.isNotEmpty)
            Wrap(
              spacing: 4,
              children: [
                for (final id in slipIds)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: DplColors.success, width: 0.8),
                    ),
                    child: Text(
                      'Slip #$id',
                      style: const TextStyle(
                        color: DplColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _TripHeader extends StatelessWidget {
  final DplTrip trip;
  const _TripHeader({required this.trip});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final isPartial = trip.status == DplTripStatus.partial;
    return Container(
      decoration: const BoxDecoration(
        color: DplColors.primaryTint,
        borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_rounded,
              color: DplColors.primaryDark, size: 20),
          const SizedBox(width: 8),
          Text(
            'Trip ${trip.tripNumber}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: DplColors.primaryDark,
            ),
          ),
          const SizedBox(width: 8),
          if (trip.plantName.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                trip.plantName,
                style: const TextStyle(
                  color: DplColors.primaryDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ),
          const SizedBox(width: 6),
          if (isPartial)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: DplColors.warningBg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Partial',
                style: TextStyle(
                  color: DplColors.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                ),
              ),
            ),
          const Spacer(),
          Text(
            '${fmt.format(trip.openQty ?? 0)} / '
            '${fmt.format(trip.totalQty ?? 0)} NOS',
            style: const TextStyle(
              color: DplColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  final DplTripPlan plan;
  final bool isSelected;
  final int qty;
  final String varianceNote;

  /// Available-for-dispatch qty on the matching `(machine, part)`
  /// bucket. `null` while the production-summary cache is still
  /// loading — the row renders without a cap in that window. `0`
  /// means "no produced inventory" → checkbox is disabled upstream
  /// by `_toggleHandlerFor` returning null.
  final int? available;
  final VoidCallback? onToggle;
  final ValueChanged<int> onQtyChanged;
  final ValueChanged<String> onVarianceChanged;
  const _PlanRow({
    required this.plan,
    required this.isSelected,
    required this.qty,
    required this.varianceNote,
    required this.available,
    required this.onToggle,
    required this.onQtyChanged,
    required this.onVarianceChanged,
  });

  /// True when the plan's *business* status permits booking (status =
  /// open). Independent from stock — a business-bookable plan with
  /// zero produced inventory is still bookable in principle, just
  /// blocked until production catches up.
  bool get _isBookable => onToggle != null;
  bool get _qtyReduced => qty < plan.qty;

  /// Hard cap on qty input — now just the planned qty. The previous
  /// "min(planned, available)" cap was lifted with the stock gate
  /// (operator request) so a dispatcher can submit against the
  /// planned qty even when production hasn't caught up yet; the
  /// backend retains the authoritative INSUFFICIENT_QTY check.
  int get _maxBookable => plan.qty;

  bool get _outOfStock => available == 0;

  /// Checkbox tap-ability. Only the business status (plan must be
  /// `open`) gates this now — stock is no longer a hard block.
  bool get _canTick => _isBookable;

  @override
  Widget build(BuildContext context) {
    final accent = !_isBookable
        ? DplColors.neutralBg
        : (_outOfStock
            ? DplColors.warningBg
            : (isSelected ? DplColors.primaryTint : DplColors.cardBg));
    return Container(
      color: accent,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: isSelected,
                onChanged: _canTick ? (_) => onToggle!() : null,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: DplColors.primaryTint,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  plan.description.isEmpty ? '-' : plan.description,
                  style: const TextStyle(
                    color: DplColors.primaryDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.partName.isEmpty ? plan.customerPn : plan.partName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plan.machineName.isNotEmpty)
                      Text(
                        plan.machineName,
                        style: const TextStyle(
                          color: DplColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 10.5,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 78,
                child: _QtyField(
                  qty: qty,
                  maxQty: _maxBookable,
                  plannedQty: plan.qty,
                  enabled: _isBookable,
                  // `hasError: false` — over-available is now a soft
                  // info state, not a hard error, so the field no
                  // longer turns red.
                  hasError: false,
                  onChanged: onQtyChanged,
                ),
              ),
            ],
          ),
          // Availability hint — surfaced ONLY when production-summary
          // has loaded. Out-of-stock shows the strongest warning since
          // the row is locked out entirely; over-available means the
          // current qty exceeds what's produced and submit is blocked;
          // otherwise we render a quiet "X NOS available" badge so the
          // dispatcher knows the headroom.
          if (_isBookable && available != null)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: _AvailabilityHint(
                available: available!,
                plannedQty: plan.qty,
                currentQty: qty,
              ),
            ),
          // Packaging-qty hint — bears no relationship to stock, so
          // it renders independently of `_outOfStock`. When the plan
          // qty isn't a multiple of the pack, render a soft warning
          // with one-tap "nearest multiple" chips. Backend doesn't
          // enforce; partial packs are valid.
          if (_isBookable && plan.packagingQty != null && plan.packagingQty! > 0)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: _PackHint(
                pack: plan.packagingQty!,
                qty: qty,
                onApply: onQtyChanged,
              ),
            ),
          if (!_isBookable)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 4),
              child: Text(
                _statusLabel(plan),
                style: const TextStyle(
                  color: DplColors.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 10.5,
                ),
              ),
            ),
          if (_isBookable && _qtyReduced)
            Padding(
              padding: const EdgeInsets.only(left: 32, top: 6, right: 0),
              child: TextField(
                onChanged: onVarianceChanged,
                maxLength: 240,
                decoration: InputDecoration(
                  isDense: true,
                  prefixIcon: const Icon(Icons.flag_outlined,
                      size: 16, color: DplColors.warning),
                  hintText:
                      'Variance note (required — qty reduced by ${plan.qty - qty})',
                  hintStyle: const TextStyle(
                    color: DplColors.warning,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 8),
                  counterText: '',
                ),
                controller: TextEditingController(text: varianceNote)
                  ..selection = TextSelection.collapsed(
                      offset: varianceNote.length),
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  static String _statusLabel(DplTripPlan p) {
    final slipRef = p.slipId == null ? '' : '#${p.slipId}';
    switch (p.status) {
      case DplTripPlanStatus.slipCreated:
        return 'In slip $slipRef';
      case DplTripPlanStatus.dispatched:
        return 'Dispatched in slip $slipRef';
      case DplTripPlanStatus.cancelled:
        return 'Cancelled';
      default:
        return p.status;
    }
  }
}

class _QtyField extends StatefulWidget {
  final int qty;

  /// Hard cap for input — `min(plannedQty, availableQty)`. Caller
  /// resolves this so we never paste a value the backend would reject.
  final int maxQty;

  /// Original trip-plan qty. Surfaced under the field as `max N` so
  /// the dispatcher still sees the manager's intent even when stock
  /// constraints have lowered the bookable cap below it.
  final int plannedQty;
  final bool enabled;

  /// Renders the field with the error color when the current qty
  /// exceeds what's available — visual reinforcement of the inline
  /// "Reduce qty" hint below the row.
  final bool hasError;
  final ValueChanged<int> onChanged;
  const _QtyField({
    required this.qty,
    required this.maxQty,
    required this.plannedQty,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
  });

  @override
  State<_QtyField> createState() => _QtyFieldState();
}

class _QtyFieldState extends State<_QtyField> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.qty}');
  }

  @override
  void didUpdateWidget(covariant _QtyField old) {
    super.didUpdateWidget(old);
    // Stay in sync when the parent resets (e.g. after Send for PDI
    // clears all local state) but never overwrite while the user is
    // typing.
    if (widget.qty != old.qty &&
        int.tryParse(_ctrl.text.trim()) != widget.qty) {
      _ctrl.text = '${widget.qty}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Field reads as "warning" when the dispatcher is below the
    // manager's planned qty (variance flow), and as "error" when the
    // current qty is above what production can fulfil (over-available
    // signal pushed in from the parent).
    final reduced = widget.qty < widget.plannedQty;
    final inkColor = widget.hasError
        ? DplColors.error
        : (reduced ? DplColors.warning : DplColors.textPrimary);
    final borderColor = widget.hasError ? DplColors.error : DplColors.divider;
    return TextField(
      controller: _ctrl,
      enabled: widget.enabled,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 13,
        color: inkColor,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        helperText: 'max ${widget.plannedQty}',
        helperStyle: const TextStyle(
          fontSize: 9.5,
          color: DplColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        helperMaxLines: 1,
      ),
      onChanged: (v) {
        final n = int.tryParse(v.trim()) ?? 0;
        // Cap at the effective max (min of planned, available).
        // We don't snap the visible value back here because that
        // would surprise the user if they're mid-typing — we only
        // emit the capped value upstream; the over-available state
        // turns the field red so they know to reduce.
        final capped = n > widget.maxQty ? widget.maxQty : n;
        widget.onChanged(capped);
      },
    );
  }
}

/// One-line availability hint rendered under each bookable plan row.
/// Three states:
///   * stock = 0           → bold "Out of stock" warning
///   * current > available → red "Reduce qty — only N NOS available"
///   * stock available     → quiet "N NOS available"
/// One-line "Pack: N NOS" hint with a soft amber warning when the
/// current qty isn't a multiple of the pack. The warning offers
/// one-tap chips for the nearest multiples (below + above). Backend
/// doesn't enforce pack multiples — partial packs are valid for
/// stock-short or pilot scenarios — so this is informational only.
class _PackHint extends StatelessWidget {
  final int pack;
  final int qty;
  final ValueChanged<int> onApply;
  const _PackHint({
    required this.pack,
    required this.qty,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final isMultiple = qty > 0 && qty % pack == 0;

    if (qty == 0 || isMultiple) {
      // Clean state — just inform the dispatcher of the pack size.
      return Row(
        children: [
          const Icon(Icons.all_inbox_outlined,
              size: 13, color: DplColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            'Pack: ${fmt.format(pack)} NOS',
            style: const TextStyle(
              color: DplColors.textSecondary,
              fontWeight: FontWeight.w700,
              fontSize: 10.5,
            ),
          ),
        ],
      );
    }

    final lower = (qty ~/ pack) * pack;
    final upper = lower + pack;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 4,
      children: [
        const Icon(Icons.warning_amber_rounded,
            size: 13, color: DplColors.warning),
        Text(
          'Not a multiple of $pack — try',
          style: const TextStyle(
            color: DplColors.warning,
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
          ),
        ),
        if (lower > 0)
          _PackSuggestionChip(value: lower, onTap: () => onApply(lower)),
        _PackSuggestionChip(value: upper, onTap: () => onApply(upper)),
      ],
    );
  }
}

class _PackSuggestionChip extends StatelessWidget {
  final int value;
  final VoidCallback onTap;
  const _PackSuggestionChip({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: DplColors.warningBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: DplColors.warning, width: 0.8),
        ),
        child: Text(
          '$value',
          style: const TextStyle(
            color: DplColors.warning,
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
          ),
        ),
      ),
    );
  }
}

class _AvailabilityHint extends StatelessWidget {
  final int available;
  final int plannedQty;
  final int currentQty;
  const _AvailabilityHint({
    required this.available,
    required this.plannedQty,
    required this.currentQty,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    if (available == 0) {
      return Row(
        children: const [
          Icon(Icons.block_rounded, size: 13, color: DplColors.warning),
          SizedBox(width: 4),
          Text(
            'Out of stock — wait for production to complete.',
            style: TextStyle(
              color: DplColors.warning,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      );
    }
    if (currentQty > available) {
      return Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 13, color: DplColors.error),
          const SizedBox(width: 4),
          Text(
            'Reduce qty — only ${fmt.format(available)} NOS available.',
            style: const TextStyle(
              color: DplColors.error,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.inventory_2_outlined,
            size: 13, color: DplColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          '${fmt.format(available)} NOS available · planned ${fmt.format(plannedQty)}',
          style: const TextStyle(
            color: DplColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _OptionalText extends StatelessWidget {
  final TextEditingController controller;
  final IconData icon;
  final String hint;
  final int maxLength;
  final int maxLines;

  /// When true, the field renders with a subtle red border + error
  /// text whenever [showError] is set. Visual signal that the caller
  /// is treating this as required.
  final bool required;
  final bool showError;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  const _OptionalText({
    required this.controller,
    required this.icon,
    required this.hint,
    required this.maxLength,
    this.maxLines = 1,
    this.required = false,
    this.showError = false,
    this.errorText,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor =
        showError ? DplColors.error : DplColors.divider;
    final iconColor =
        showError ? DplColors.error : DplColors.textSecondary;
    return TextField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 12.5),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(icon, size: 18, color: iconColor),
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 12.5,
          color: required
              ? DplColors.textSecondary
              : DplColors.textTertiary,
          fontWeight: required ? FontWeight.w700 : FontWeight.normal,
        ),
        errorText: showError ? errorText : null,
        errorStyle: const TextStyle(
          fontSize: 11,
          color: DplColors.error,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: borderColor),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        counterText: '',
      ),
    );
  }
}
