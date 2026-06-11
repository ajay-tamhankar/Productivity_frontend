import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../auth/auth_provider.dart';
import '../../core/design/dpl_theme.dart';
import '../../core/dpl_constants.dart';
import '../../core/dpl_organization_provider.dart';
import '../../core/widgets/dpl_app_bar.dart';
import '../../core/widgets/dpl_snack.dart';
import '../../manager/widgets/error_retry.dart';
import '../../models/dpl_dispatch_slip.dart';
import '../providers/dispatch_slips_provider.dart';
import '../services/dispatch_slip_pdf.dart';
import '../widgets/dispatch_slip_actions.dart';
import '../widgets/dispatch_slip_status_badge.dart';

/// Printable detail view of a single dispatch slip.
///
/// Visual structure mirrors the printed paper slip in the user's photo:
/// bordered rows for the part description / customer P/N / qty / time,
/// QA + PDI signature blocks (digital — name + timestamp), and a large
/// QR code at the bottom that anyone can scan to verify authenticity
/// against the public `/dispatch/slips/verify` endpoint.
///
/// Below the printable area we render role-aware action buttons:
///   * `dpl_qa` on a `pending_qa` slip → Approve / Reject
///   * `dpl_pdi` on a `pending_pdi` slip → Approve / Reject
///   * `dpl_dispatch` on an `approved` slip → Mark dispatched
class DispatchSlipDetailScreen extends ConsumerWidget {
  final int slipId;
  const DispatchSlipDetailScreen({super.key, required this.slipId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dplDispatchSlipDetailProvider(slipId));
    final role = ref.watch(authControllerProvider).asData?.value?.role ?? '';

    final slipForActions = async.asData?.value.data;

    return Scaffold(
      backgroundColor: DplColors.pageBg,
      appBar: DplAppBar(
        title: 'Dispatch Slip',
        actions: [
          IconButton(
            tooltip: 'Print / Save PDF',
            icon: const Icon(Icons.print_outlined),
            onPressed: slipForActions == null
                ? null
                : () => _printSlip(context, ref, slipForActions),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => DplErrorRetry(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(dplDispatchSlipDetailProvider(slipId)),
        ),
        data: (res) {
          if (res.isError || res.data == null) {
            return DplErrorRetry(
              message: res.error ?? 'Failed to load slip.',
              onRetry: () =>
                  ref.invalidate(dplDispatchSlipDetailProvider(slipId)),
            );
          }
          final slip = res.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeaderSummary(slip: slip),
                const SizedBox(height: 14),
                _PrintableSlip(slip: slip),
                const SizedBox(height: 14),
                _Timeline(slip: slip),
                const SizedBox(height: 14),
                _RoleActions(slip: slip, role: role),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Hands the slip's PDF to the OS print sheet via the `printing`
  /// package. Works on Android (system print dialog), iOS (AirPrint
  /// sheet), and web (browser print preview). The PDF mirrors the
  /// on-screen printable layout exactly, with the same QA / PDI state
  /// labels and the QR code embedded as a vector barcode (so it stays
  /// crisp regardless of print DPI).
  Future<void> _printSlip(
    BuildContext context,
    WidgetRef ref,
    DplDispatchSlip slip,
  ) async {
    try {
      final orgLabel =
          ref.read(dplActiveOrganizationProvider)?.displayLabel;
      await Printing.layoutPdf(
        name: 'Dispatch-${slip.slipNo}',
        onLayout: (_) => DispatchSlipPdfBuilder.build(
          slip,
          organizationLabel: orgLabel,
        ),
      );
    } on MissingPluginException {
      // Almost always means the running app binary predates the
      // `printing` plugin being added to pubspec — the Dart side calls
      // through but no native handler is registered. Hot restart can't
      // fix this; the user has to fully stop + rebuild.
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
}

/// Compact slip-number + status block above the printable area. Gives
/// the user immediate context before they scroll.
class _HeaderSummary extends StatelessWidget {
  final DplDispatchSlip slip;
  const _HeaderSummary({required this.slip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
        boxShadow: DplShadows.card,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  slip.slipNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${slip.machineLabel} • Qty ${slip.qty}',
                  style: const TextStyle(
                    color: DplColors.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          DispatchSlipStatusBadge(status: slip.status),
        ],
      ),
    );
  }
}

/// The boxed slip body matching the printed paper format.
///
/// Row order matches the physical slip in the user's reference photo:
///   1. Full part description (the big bold "TIAGO 6AB HL ASSY…" line)
///   2. Customer part number
///   3. Qty
///   4. Reference datetime
///   5. QA + PDI signature blocks — each carries an explicit state
///      label ("Approved by QA" / "Pending QA" / "Rejected by QA") so
///      anyone holding the paper instantly knows where the workflow
///      stands without cross-referencing the status badge.
///   6. QR + human-readable "Slip contents" panel so the slip is
///      readable by eye even without a scanner.
class _PrintableSlip extends StatelessWidget {
  final DplDispatchSlip slip;
  const _PrintableSlip({required this.slip});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('d-M-yy  h:mm a');

    // Prefer the long part name (e.g. "TIAGO 6AB HL ASSY NW W MIC WO
    // RLS,F") so the slip leads with the human-readable description.
    // Falls back through `description` and then the generic
    // `partLabel` so this row is never empty.
    final partTitle = (slip.partName.trim().isNotEmpty
            ? slip.partName
            : (slip.description.trim().isNotEmpty
                ? slip.description
                : slip.partLabel))
        .toUpperCase();

    final referenceTime = slip.pdiApproval?.at ??
        slip.qaApproval?.at ??
        slip.requestedAt;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.textPrimary, width: 1.5),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Row 1 — full part description.
          _SlipRow(
            child: Text(
              partTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                letterSpacing: 0.2,
                height: 1.25,
              ),
            ),
          ),
          // Row 2 — customer part number.
          _SlipRow(
            child: Text(
              slip.customerPartNo.isEmpty ? '-' : slip.customerPartNo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: 0.6,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          // Row 3 — qty.
          _SlipRow(
            child: Text(
              'QTY: ${fmt.format(slip.qty)} NOS',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 0.4,
              ),
            ),
          ),
          // Row 4 — reference timestamp.
          _SlipRow(
            child: Text(
              referenceTime == null
                  ? '-'
                  : dateFmt.format(referenceTime.toLocal()),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          // Row 5 — QA + PDI signature row with explicit state labels.
          _SlipRow(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _SignatureBlock(
                    station: 'QA',
                    state: slip.qaState,
                    name: slip.qaApproval?.name,
                    at: slip.qaApproval?.at,
                    rejection:
                        slip.rejection?.isQa == true ? slip.rejection : null,
                  ),
                ),
                Container(
                  width: 1,
                  height: 64,
                  color: DplColors.textPrimary,
                ),
                Expanded(
                  child: _SignatureBlock(
                    station: 'PDI',
                    state: slip.pdiState,
                    name: slip.pdiApproval?.name,
                    at: slip.pdiApproval?.at,
                    rejection:
                        slip.rejection?.isPdi == true ? slip.rejection : null,
                  ),
                ),
              ],
            ),
          ),
          // Row 6 — QR + human-readable contents side-by-side.
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _QrPanel(slip: slip),
          ),
        ],
      ),
    );
  }
}

class _SlipRow extends StatelessWidget {
  final Widget child;
  const _SlipRow({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: DplColors.textPrimary),
        ),
      ),
      child: child,
    );
  }
}

/// Per-station signature block. The pill text now carries the
/// **actual user name** instead of the role abbreviation, so a glance
/// reads "APPROVED BY DPL QA" instead of the redundant "APPROVED BY QA"
/// + a separate italic "DPL QA" line. We keep a tiny "QA" / "PDI"
/// station header above the pill so each side is still self-identifying.
///
///   * `approved` — green "APPROVED BY {approver}" pill + timestamp.
///   * `pending`  — amber "PENDING" pill, no name yet, no timestamp.
///   * `rejected` — red "REJECTED BY {rejecter}" pill + timestamp +
///     reason in quotes.
class _SignatureBlock extends StatelessWidget {
  final String station;
  final DispatchStationState state;
  final String? name;
  final DateTime? at;
  final DplDispatchSlipRejection? rejection;

  const _SignatureBlock({
    required this.station,
    required this.state,
    required this.name,
    required this.at,
    required this.rejection,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM, HH:mm');
    final palette = _paletteFor(state);

    final approverName = switch (state) {
      DispatchStationState.approved =>
        (name?.trim().isEmpty ?? true) ? null : name!.trim(),
      DispatchStationState.rejected =>
        (rejection?.name.trim().isEmpty ?? true)
            ? null
            : rejection!.name.trim(),
      DispatchStationState.pending => null,
    };
    final pillText = switch (state) {
      DispatchStationState.approved =>
        'APPROVED BY ${approverName ?? "—"}',
      DispatchStationState.pending => 'PENDING',
      DispatchStationState.rejected =>
        'REJECTED BY ${approverName ?? "—"}',
    };
    final stamped = switch (state) {
      DispatchStationState.approved => at,
      DispatchStationState.rejected => rejection?.at,
      DispatchStationState.pending => null,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Small station header so each side is self-identifying.
          Text(
            station,
            style: const TextStyle(
              color: DplColors.textSecondary,
              fontWeight: FontWeight.w800,
              fontSize: 10,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          // State + name pill — the line the user actually reads.
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: palette.bg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              pillText,
              style: TextStyle(
                color: palette.fg,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
                letterSpacing: 0.3,
                height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (stamped != null) ...[
            const SizedBox(height: 4),
            Text(
              dateFmt.format(stamped.toLocal()),
              style: const TextStyle(
                color: DplColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
              ),
            ),
          ],
          if (state == DispatchStationState.rejected &&
              rejection != null &&
              rejection!.reason.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '"${rejection!.reason.trim()}"',
              style: const TextStyle(
                color: DplColors.error,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
                fontSize: 11,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  _SignaturePalette _paletteFor(DispatchStationState state) {
    switch (state) {
      case DispatchStationState.approved:
        return const _SignaturePalette(DplColors.success, DplColors.successBg);
      case DispatchStationState.pending:
        return const _SignaturePalette(DplColors.warning, DplColors.warningBg);
      case DispatchStationState.rejected:
        return const _SignaturePalette(DplColors.error, DplColors.errorBg);
    }
  }
}

class _SignaturePalette {
  final Color fg;
  final Color bg;
  const _SignaturePalette(this.fg, this.bg);
}

/// QR + human-readable contents.
///
/// The QR encodes an HMAC-signed token the backend generates on PDI
/// approval — it's deliberately *not* human readable so the slip can't
/// be forged just by copying the on-paper text. To still let anyone
/// holding the paper read the slip by eye, we render a "Slip contents"
/// panel right next to the QR with every field in plain text + a short
/// note explaining what the QR is for.
class _QrPanel extends StatelessWidget {
  final DplDispatchSlip slip;
  const _QrPanel({required this.slip});

  @override
  Widget build(BuildContext context) {
    final payload = slip.qrPayload;
    final hasQr = payload != null && payload.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // QR (or placeholder when slip isn't yet PDI-approved).
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 156,
              height: 156,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasQr ? Colors.white : DplColors.pageBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: hasQr
                      ? DplColors.textPrimary
                      : DplColors.divider,
                ),
              ),
              child: hasQr
                  ? QrImageView(
                      data: payload,
                      version: QrVersions.auto,
                      // High EC so a scuff on the printed paper still
                      // scans cleanly at the warehouse gate.
                      errorCorrectionLevel: QrErrorCorrectLevel.H,
                      gapless: true,
                    )
                  : const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          'QR appears after PDI approval',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: DplColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              slip.slipNo,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: DplColors.textSecondary,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        // Human-readable contents.
        Expanded(child: _SlipContentsPanel(slip: slip, signed: hasQr)),
      ],
    );
  }
}

/// Plain-text summary of everything the QR encodes — so a person who
/// can't scan (no scanner, dead phone, etc.) can still read what the
/// slip says and cross-check it. The note at the bottom explains *why*
/// the QR is opaque: a printable plaintext code could be forged, so we
/// ship a signed token instead and treat this on-paper text as the
/// "what does this slip say" cheat sheet for humans.
class _SlipContentsPanel extends StatelessWidget {
  final DplDispatchSlip slip;
  final bool signed;
  const _SlipContentsPanel({required this.slip, required this.signed});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');

    final rows = <Widget>[
      _ContentRow(label: 'Slip no', value: slip.slipNo),
      _ContentRow(label: 'Machine', value: slip.machineLabel),
      _ContentRow(
        label: 'Customer P/N',
        value: slip.customerPartNo.isEmpty ? '-' : slip.customerPartNo,
      ),
      _ContentRow(label: 'Qty', value: '${fmt.format(slip.qty)} NOS'),
      if (slip.qaApproval != null && slip.qaApproval!.at != null)
        _ContentRow(
          label: 'QA approved',
          value:
              '${slip.qaApproval!.name} • ${dateFmt.format(slip.qaApproval!.at!.toLocal())}',
        ),
      if (slip.pdiApproval != null && slip.pdiApproval!.at != null)
        _ContentRow(
          label: 'PDI approved',
          value:
              '${slip.pdiApproval!.name} • ${dateFmt.format(slip.pdiApproval!.at!.toLocal())}',
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'SLIP CONTENTS',
          style: TextStyle(
            color: DplColors.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        ...rows,
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: DplColors.pageBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: DplColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                signed
                    ? Icons.verified_user_outlined
                    : Icons.lock_clock_outlined,
                size: 14,
                color: signed ? DplColors.success : DplColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  signed
                      ? 'Scan QR to verify against the Vistar Pulse server. '
                          'The code is HMAC-signed — tampered slips fail verification.'
                      : 'The QR is generated and signed by the server once PDI approves.',
                  style: const TextStyle(
                    color: DplColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContentRow extends StatelessWidget {
  final String label;
  final String value;
  const _ContentRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                color: DplColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: DplColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact timeline of who did what (created → QA → PDI → dispatched).
/// Helps QA/PDI confirm they're acting on the right slip before tapping
/// approve, and gives Dispatch a one-glance audit trail.
class _Timeline extends StatelessWidget {
  final DplDispatchSlip slip;
  const _Timeline({required this.slip});

  @override
  Widget build(BuildContext context) {
    final entries = <_TimelineEntry>[
      if (slip.requestedBy != null || slip.requestedAt != null)
        _TimelineEntry(
          icon: Icons.send_outlined,
          label: 'Requested by ${slip.requestedBy?.name ?? "-"}',
          at: slip.requestedAt,
        ),
      if (slip.qaApproval != null)
        _TimelineEntry(
          icon: Icons.verified_outlined,
          label: 'QA approved by ${slip.qaApproval!.name}',
          at: slip.qaApproval!.at,
          remarks: slip.qaApproval!.remarks,
        ),
      if (slip.pdiApproval != null)
        _TimelineEntry(
          icon: Icons.check_circle_outline,
          label: 'PDI approved by ${slip.pdiApproval!.name}',
          at: slip.pdiApproval!.at,
          remarks: slip.pdiApproval!.remarks,
        ),
      if (slip.rejection != null)
        _TimelineEntry(
          icon: Icons.cancel_outlined,
          label:
              '${slip.rejection!.role.toUpperCase()} rejected by ${slip.rejection!.name}',
          at: slip.rejection!.at,
          remarks: slip.rejection!.reason,
          danger: true,
        ),
      if (slip.dispatchedAt != null)
        _TimelineEntry(
          icon: Icons.local_shipping_outlined,
          label: 'Dispatched by ${slip.dispatchedBy?.name ?? "-"}',
          at: slip.dispatchedAt,
        ),
    ];

    if (entries.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Activity', style: DplText.h3()),
          const SizedBox(height: 8),
          for (final e in entries) ...[
            _TimelineRow(entry: e),
            if (e != entries.last)
              const Divider(
                height: 12,
                color: DplColors.divider,
              ),
          ],
        ],
      ),
    );
  }
}

class _TimelineEntry {
  final IconData icon;
  final String label;
  final DateTime? at;
  final String? remarks;
  final bool danger;
  const _TimelineEntry({
    required this.icon,
    required this.label,
    required this.at,
    this.remarks,
    this.danger = false,
  });
}

class _TimelineRow extends StatelessWidget {
  final _TimelineEntry entry;
  const _TimelineRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy, HH:mm');
    final color = entry.danger ? DplColors.error : DplColors.primaryDark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                entry.danger ? DplColors.errorBg : DplColors.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(entry.icon, size: 16, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              if (entry.at != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    dateFmt.format(entry.at!.toLocal()),
                    style: const TextStyle(
                      color: DplColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              if (entry.remarks != null && entry.remarks!.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '"${entry.remarks!.trim()}"',
                    style: TextStyle(
                      color: entry.danger
                          ? DplColors.error
                          : DplColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Role-aware action bar at the bottom. Only the actions valid for the
/// user's role on the slip's current status are rendered — the rest are
/// hidden to keep the screen unambiguous.
class _RoleActions extends ConsumerWidget {
  final DplDispatchSlip slip;
  final String role;
  const _RoleActions({required this.slip, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isQa = AppConstants.isDplQaRole(role);
    final isPdi = AppConstants.isDplPdiRole(role);
    final isDispatch = AppConstants.isDplDispatchRole(role);
    final isManager = AppConstants.isDplManagerRole(role);

    final canQaAct =
        (isQa || isManager) && slip.status == DplDispatchSlipStatus.pendingQa;
    final canPdiAct = (isPdi || isManager) &&
        slip.status == DplDispatchSlipStatus.pendingPdi;
    final canDispatch = (isDispatch || isManager) &&
        slip.status == DplDispatchSlipStatus.approved;

    if (!canQaAct && !canPdiAct && !canDispatch) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DplColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Actions', style: DplText.h3()),
          const SizedBox(height: 10),
          if (canQaAct)
            _ApprovalRow(
              approveAction: DispatchSlipApprovalAction.qaApprove,
              rejectAction: DispatchSlipApprovalAction.qaReject,
              slip: slip,
            ),
          if (canPdiAct)
            _ApprovalRow(
              approveAction: DispatchSlipApprovalAction.pdiApprove,
              rejectAction: DispatchSlipApprovalAction.pdiReject,
              slip: slip,
            ),
          if (canDispatch)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => MarkDispatchedConfirmDialog.show(
                      context,
                      ref,
                      slip: slip,
                    ),
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text('Mark Dispatched'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  final DispatchSlipApprovalAction approveAction;
  final DispatchSlipApprovalAction rejectAction;
  final DplDispatchSlip slip;
  const _ApprovalRow({
    required this.approveAction,
    required this.rejectAction,
    required this.slip,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: DplColors.error,
              side: const BorderSide(color: DplColors.error),
            ),
            onPressed: () => DispatchSlipActionSheet.show(
              context,
              slip: slip,
              action: rejectAction,
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Reject'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: () => DispatchSlipActionSheet.show(
              context,
              slip: slip,
              action: approveAction,
            ),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Approve'),
          ),
        ),
      ],
    );
  }
}
