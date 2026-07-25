import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/design/dpl_theme.dart';
import '../../core/dpl_api_service.dart';
import '../../core/widgets/dpl_app_bar.dart';
import '../../models/dpl_consolidated_slip.dart';

/// Consolidated one-page trip slip — shown to dispatch / manager for
/// preview + hand-off to the driver's phone. Renders the trip QR (which
/// Security scans at Gate Out), a compact trip fact card, and a single
/// combined table listing every slip in the trip.
///
/// The QR is signed server-side (HMAC via DPL_DISPATCH_QR_SECRET); the
/// FE just displays the token, never decodes it.
class ConsolidatedSlipScreen extends ConsumerStatefulWidget {
  final int tripId;
  const ConsolidatedSlipScreen({super.key, required this.tripId});

  @override
  ConsumerState<ConsolidatedSlipScreen> createState() =>
      _ConsolidatedSlipScreenState();
}

class _ConsolidatedSlipScreenState
    extends ConsumerState<ConsolidatedSlipScreen> {
  Future<DplConsolidatedSlip>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DplConsolidatedSlip> _load() async {
    final api = ref.read(dplApiServiceProvider);
    final res = await api.getConsolidatedSlip(widget.tripId);
    if (res.isError || res.data == null) {
      throw Exception(res.error ?? 'Failed to load consolidated slip');
    }
    return res.data!;
  }

  Future<void> _refresh() async {
    final fresh = _load();
    setState(() => _future = fresh);
    await fresh;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DplColors.pageBg,
      appBar: DplAppBar(
        title: 'Consolidated Slip',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<DplConsolidatedSlip>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: DplColors.error, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      snap.error.toString().replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _refresh,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _buildContent(snap.data!);
        },
      ),
    );
  }

  Widget _buildContent(DplConsolidatedSlip data) {
    final trip = data.trip;
    final slips = data.slips;
    final totalQty = slips.fold<int>(
      0,
      (s, x) => s + x.totalQty,
    );
    final fmt = NumberFormat.decimalPattern();
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── QR + Trip header ───────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DplColors.divider),
              boxShadow: DplShadows.card,
            ),
            child: Column(
              children: [
                Text(
                  'Trip #${trip.tripNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (trip.plantName.isNotEmpty) trip.plantName,
                    if ((trip.vehicleNo ?? '').isNotEmpty) trip.vehicleNo!,
                  ].join(' · '),
                  style: const TextStyle(color: DplColors.textSecondary),
                ),
                const SizedBox(height: 16),
                if (data.qrToken.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.white,
                    child: QrImageView(
                      data: data.qrToken,
                      version: QrVersions.auto,
                      size: 220,
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'QR token not available — refresh to retry.',
                      style: TextStyle(color: DplColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Show this QR at Origin Gate (Security) and TATA Dock (QRE).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: DplColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Trip facts strip ────────────────────────────────────
          _factsCard(trip, totalQty, fmt, slips.length),

          const SizedBox(height: 14),

          // ── Slip table ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: DplColors.divider),
              boxShadow: DplShadows.card,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${slips.length} slip${slips.length == 1 ? '' : 's'} in this trip',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 32,
                    dataRowMinHeight: 28,
                    dataRowMaxHeight: 44,
                    columnSpacing: 20,
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('Slip No')),
                      DataColumn(label: Text('Invoice')),
                      DataColumn(label: Text('Qty'), numeric: true),
                    ],
                    rows: [
                      for (var i = 0; i < slips.length; i++)
                        DataRow(
                          cells: [
                            DataCell(Text('${i + 1}')),
                            DataCell(Text(slips[i].slipNo,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            DataCell(Text(slips[i].invoiceNo ?? '—')),
                            DataCell(Text(fmt.format(slips[i].totalQty))),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _factsCard(trip, int totalQty, NumberFormat fmt, int slipCount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _factRow('Plant', trip.plantName.isNotEmpty
              ? trip.plantName
              : trip.plantCode),
          _factRow('Vehicle', (trip.vehicleNo ?? '—')),
          _factRow('Total Qty', '${fmt.format(totalQty)} NOS'),
          _factRow('Slips', '$slipCount'),
          if ((trip.driverName ?? '').isNotEmpty)
            _factRow('Driver', trip.driverName!),
        ],
      ),
    );
  }

  Widget _factRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: DplColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
