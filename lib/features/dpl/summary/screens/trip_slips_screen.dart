import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../../core/design/dpl_theme.dart';
import '../../core/dpl_api_service.dart';
import '../../core/dpl_constants.dart';
import '../../core/dpl_organization_provider.dart';
import '../../core/widgets/dpl_app_bar.dart';
import '../../core/widgets/dpl_snack.dart';
import '../../models/dpl_dispatch_slip.dart';
import '../services/dispatch_slip_pdf.dart';
import '../widgets/dispatch_slip_status_badge.dart';
import 'dispatch_slip_detail_screen.dart';

/// Single-screen view of every slip cut from one manager-submitted
/// trip. Replaces the "scroll past N near-identical slip cards in the
/// inbox" UX with one card per trip → tap → this screen shows the
/// trip's slip stack in order, scrollable, with a single Print-all
/// action that produces one multi-page PDF (one A4-landscape page per
/// slip).
///
/// The slips are passed in from the inbox (the same snapshot the
/// inbox is showing). Tapping a slip pushes the existing
/// [DispatchSlipDetailScreen] so QA / PDI / Dispatch actions and the
/// scan-to-act flow are unchanged.
class TripSlipsScreen extends ConsumerStatefulWidget {
  final int? tripId;
  final int tripNumber;
  final String plantCode;
  final String plantName;
  final List<DplDispatchSlip> slips;

  const TripSlipsScreen({
    super.key,
    required this.tripId,
    required this.tripNumber,
    required this.plantCode,
    required this.plantName,
    required this.slips,
  });

  @override
  ConsumerState<TripSlipsScreen> createState() => _TripSlipsScreenState();
}

class _TripSlipsScreenState extends ConsumerState<TripSlipsScreen> {
  /// Guards the AppBar Email-all button so back-to-back taps can't fire
  /// N concurrent uploads. Rendering all PDFs + posting is sequential
  /// (one slip at a time) so SMTP throttling on the server stays sane.
  bool _emailing = false;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final slips = widget.slips;
    final totalQty =
        slips.fold<int>(0, (s, x) => s + x.totalQty);
    final plantLabel =
        widget.plantName.isNotEmpty ? widget.plantName : widget.plantCode;

    return Scaffold(
      backgroundColor: DplColors.pageBg,
      appBar: DplAppBar(
        title: 'Trip #${widget.tripNumber}',
        actions: [
          IconButton(
            tooltip: _emailing
                ? 'Emailing trip PDF…'
                : slips.length == 1
                    ? 'Email slip to Dispatch'
                    : 'Email all ${slips.length} slips as one PDF',
            icon: _emailing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.mail_outline_rounded),
            onPressed: (slips.isEmpty || _emailing)
                ? null
                : () => _emailAll(context),
          ),
          IconButton(
            tooltip: 'Print all (${slips.length}-page PDF)',
            icon: const Icon(Icons.print_outlined),
            onPressed: slips.isEmpty ? null : () => _printAll(context),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: slips.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          if (i == 0) {
            return _TripSummaryCard(
              tripNumber: widget.tripNumber,
              plantLabel: plantLabel,
              slipCount: slips.length,
              totalQty: totalQty,
              fmt: fmt,
            );
          }
          final slip = slips[i - 1];
          return _SlipDetailTile(
            slip: slip,
            index: i,
            total: slips.length,
            fmt: fmt,
          );
        },
      ),
    );
  }

  /// Builds a multi-page PDF — one page per slip in [widget.slips] order
  /// — and hands it to the OS print sheet via the `printing` plugin.
  /// Same error surface as the single-slip print path on the detail
  /// screen.
  Future<void> _printAll(BuildContext context) async {
    final orgLabel = ref.read(dplActiveOrganizationProvider)?.displayLabel;
    final name = 'Trip-${widget.tripNumber}-'
        '${widget.plantCode.isEmpty ? "slips" : widget.plantCode}';

    try {
      await Printing.layoutPdf(
        name: name,
        onLayout: (_) => DispatchSlipPdfBuilder.buildBatch(
          widget.slips,
          organizationLabel: orgLabel,
        ),
      );
    } on MissingPluginException {
      if (context.mounted) {
        DplSnacks.error(
          context,
          'Print not available in this build. Please fully restart the '
          'app (stop + run again) so the print plugin is registered.',
        );
      }
    } catch (e) {
      if (context.mounted) {
        DplSnacks.error(context, 'Failed to open print sheet: $e');
      }
    }
  }

  /// Renders ALL slips into ONE multi-page PDF (via [buildBatch]) and
  /// POSTs it as a single multipart upload — so Dispatch receives a
  /// single email with a single PDF attachment regardless of how many
  /// slips the trip has, instead of N emails.
  ///
  /// **Endpoint quirk**: the email endpoint is keyed by slip id
  /// (`/dispatch/slips/:id/email`). With no trip-level endpoint
  /// available we aim the single POST at the FIRST slip's id and rely
  /// on `subject_suffix=Trip #N (N slips)` to mark it as a batch in
  /// the recipient inbox. We also pass `slip_ids` (every slip in the
  /// trip) so the server can build the email details table from the
  /// whole stack once it reads that field; until then the body still
  /// references only the anchor slip — see "Backend ask" in the PR
  /// description for the clean fix (a trip-level email endpoint).
  Future<void> _emailAll(BuildContext context) async {
    final slips = widget.slips;
    if (slips.isEmpty) return;

    setState(() => _emailing = true);

    final orgLabel = ref.read(dplActiveOrganizationProvider)?.displayLabel;
    final api = ref.read(dplApiServiceProvider);
    final anchor = slips.first;
    final suffix = slips.length == 1
        ? 'Trip #${widget.tripNumber}'
        : 'Trip #${widget.tripNumber} (${slips.length} slips)';
    final filename = slips.length == 1
        ? '${anchor.slipNo}.pdf'
        : 'Trip-${widget.tripNumber}-'
            '${widget.plantCode.isEmpty ? "slips" : widget.plantCode}.pdf';

    Uint8List bytes;
    try {
      bytes = await DispatchSlipPdfBuilder.buildBatch(
        slips,
        organizationLabel: orgLabel,
      );
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _emailing = false);
      DplSnacks.error(context, 'Could not render trip PDF: $e');
      return;
    }

    final res = await api.sendDispatchSlipEmail(
      anchor.id,
      pdfBytes: bytes,
      filename: filename,
      subjectSuffix: suffix,
      // Send every slip id so the server can build the email details
      // table from the whole trip, not just the anchor slip in the path.
      slipIds: slips.map((s) => s.id).toList(),
    );

    if (!context.mounted) return;
    setState(() => _emailing = false);

    if (res.isError) {
      DplSnacks.error(
        context,
        'Email failed: ${res.error ?? "unknown error"}',
      );
      return;
    }

    final data = res.data;
    if (data == null) {
      DplSnacks.error(context, 'Email response was empty.');
      return;
    }
    if (data.sent) {
      final toLabel =
          data.to.isNotEmpty ? data.to.first : 'Dispatch';
      DplSnacks.success(
        context,
        slips.length == 1
            ? 'Slip emailed to $toLabel.'
            : '${slips.length} slips emailed to $toLabel '
                'in one PDF.',
      );
    } else if (data.skipped) {
      DplSnacks.warning(
        context,
        'Trip not emailed — SMTP is not configured on this deploy.',
      );
    } else {
      DplSnacks.error(
        context,
        'Email not sent: ${data.reason ?? "unknown reason"}',
      );
    }
  }
}

/// Trip-header card: rolled-up totals for the slips visible in the
/// list below. Kept compact — the per-slip tiles carry the detail.
class _TripSummaryCard extends StatelessWidget {
  final int tripNumber;
  final String plantLabel;
  final int slipCount;
  final int totalQty;
  final NumberFormat fmt;

  const _TripSummaryCard({
    required this.tripNumber,
    required this.plantLabel,
    required this.slipCount,
    required this.totalQty,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [DplColors.primary, DplColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: DplShadows.card,
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_rounded,
              color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip #$tripNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  plantLabel,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$slipCount slip${slipCount == 1 ? "" : "s"}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${fmt.format(totalQty)} NOS',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One slip rendered inline. Shows everything the inbox card surfaced
/// (slip no, machine, part, qty, status, requester + timestamp) plus
/// the vehicle no and a sign-off strip so the user can scroll through
/// the trip's slips end-to-end without opening each one. Tap → push
/// the existing [DispatchSlipDetailScreen] for the printable surface,
/// QR scan, and role actions.
class _SlipDetailTile extends StatelessWidget {
  final DplDispatchSlip slip;
  final int index;
  final int total;
  final NumberFormat fmt;

  const _SlipDetailTile({
    required this.slip,
    required this.index,
    required this.total,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DispatchSlipDetailScreen(slipId: slip.id),
          ),
        ),
        child: Ink(
          decoration: BoxDecoration(
            color: DplColors.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DplColors.divider),
            boxShadow: DplShadows.card,
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: DplColors.primaryTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$index of $total',
                      style: const TextStyle(
                        color: DplColors.primaryDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 10.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      slip.slipNo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                        letterSpacing: 0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  DispatchSlipStatusBadge(status: slip.status, dense: true),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                slip.isSingleItem
                    ? '${slip.machineLabel} • Qty ${fmt.format(slip.qty)}'
                    : '${slip.machineLabel} • ${slip.items.length} items '
                        '• ${fmt.format(slip.totalQty)} NOS',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12.5,
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
                  fontSize: 12,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (slip.vehicleNo.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        size: 13, color: DplColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      slip.vehicleNo,
                      style: const TextStyle(
                        color: DplColors.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              _SignOffStrip(slip: slip),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 13, color: DplColors.textSecondary),
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

/// Compact three-step QA / PDI / Dispatched strip — visually mirrors
/// the printable slip's sign-off row so the user can see at a glance
/// where each slip is in the pipeline without opening it.
class _SignOffStrip extends StatelessWidget {
  final DplDispatchSlip slip;
  const _SignOffStrip({required this.slip});

  @override
  Widget build(BuildContext context) {
    final isRejected = slip.status == DplDispatchSlipStatus.rejected;
    return Row(
      children: [
        Expanded(
          child: _Step(
            label: 'QA',
            done: slip.qaApproval != null,
            rejected: isRejected && (slip.rejection?.isQa ?? false),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _Step(
            label: 'PDI',
            done: slip.pdiApproval != null,
            rejected: isRejected && (slip.rejection?.isPdi ?? false),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _Step(
            label: 'Dispatched',
            done: slip.dispatchedAt != null,
            rejected: false,
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final bool done;
  final bool rejected;
  const _Step({
    required this.label,
    required this.done,
    required this.rejected,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final IconData icon;
    if (rejected) {
      bg = DplColors.errorBg;
      fg = DplColors.error;
      icon = Icons.close_rounded;
    } else if (done) {
      bg = DplColors.successBg;
      fg = DplColors.success;
      icon = Icons.check_rounded;
    } else {
      bg = DplColors.neutralBg;
      fg = DplColors.textSecondary;
      icon = Icons.radio_button_unchecked;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w800,
              fontSize: 10.5,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
