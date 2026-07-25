import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/design/dpl_theme.dart';
import '../../core/dpl_api_service.dart';
import '../../core/widgets/dpl_app_bar.dart';
import '../../core/widgets/dpl_snack.dart';
import '../../models/dpl_consolidated_slip.dart';
import '../../models/dpl_trip_journey_event.dart';
import '../widgets/trip_journey_drawer.dart';

/// Driver's single-trip cockpit. Shows the QR (for Security / QRE to
/// scan) or the LECI-scan / TATA-Gate-Out button, depending on which
/// journey event is next.
///
/// State machine (locally derived from GET /:id/journey):
///   dispatched          → show Trip QR (Security scans → gate_out)
///   gate_out            → "Scan LECI" button (driver scans TATA paper)
///   tata_gate_in        → show Trip QR again (QRE scans → tata_dock_in)
///   tata_dock_in        → passive wait ("QRE is verifying trolleys…")
///   tata_dock_out       → "Mark TATA Gate Out" button
///   tata_gate_out       → green checkmark, "Trip complete"
///
/// Polls the journey every 15s so the driver's UI advances the moment
/// Security / QRE act on the other side.
class DriverTripScreen extends ConsumerStatefulWidget {
  final int tripId;
  const DriverTripScreen({super.key, required this.tripId});

  @override
  ConsumerState<DriverTripScreen> createState() => _DriverTripScreenState();
}

class _DriverTripScreenState extends ConsumerState<DriverTripScreen> {
  DplConsolidatedSlip? _consolidated;
  List<DplTripJourneyEvent> _events = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final api = ref.read(dplApiServiceProvider);
      final cf = api.getConsolidatedSlip(widget.tripId);
      final jf = api.listTripJourney(widget.tripId);
      final cRes = await cf;
      final jRes = await jf;
      if (cRes.isError) throw Exception(cRes.error ?? 'Failed to load trip');
      if (jRes.isError) throw Exception(jRes.error ?? 'Failed to load journey');
      if (!mounted) return;
      setState(() {
        _consolidated = cRes.data;
        _events = jRes.data ?? const [];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String get _currentStage {
    if (_events.isEmpty) return 'dispatched';
    return _events.map((e) => e.event).last;
  }

  @override
  Widget build(BuildContext context) {
    final trip = _consolidated?.trip;
    return Scaffold(
      backgroundColor: DplColors.pageBg,
      appBar: DplAppBar(
        title: trip != null ? 'Trip #${trip.tripNumber}' : 'Trip',
        actions: [
          IconButton(
            tooltip: 'View journey',
            icon: const Icon(Icons.timeline_rounded),
            onPressed: _consolidated == null
                ? null
                : () => showTripJourneyDrawer(
                      context,
                      tripId: widget.tripId,
                      tripNumber: trip?.tripNumber,
                      plantName: trip?.plantName,
                      vehicleNo: trip?.vehicleNo,
                    ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _busy ? null : () => _load(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorView(_error!)
              : _buildBody(),
    );
  }

  Widget _errorView(String msg) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: DplColors.error, size: 40),
              const SizedBox(height: 12),
              Text(msg, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              TextButton(onPressed: () => _load(), child: const Text('Retry')),
            ],
          ),
        ),
      );

  Widget _buildBody() {
    final stage = _currentStage;
    final trip = _consolidated?.trip;
    final qrToken = _consolidated?.qrToken ?? '';
    return RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _header(trip, stage),
          const SizedBox(height: 16),
          _stageBody(stage, qrToken),
        ],
      ),
    );
  }

  Widget _header(trip, String stage) {
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
          Row(
            children: [
              Expanded(
                child: Text(
                  trip != null ? 'Trip #${trip.tripNumber}' : 'Trip',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _stageChip(stage),
            ],
          ),
          if (trip != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (trip.plantName.isNotEmpty) trip.plantName,
                if ((trip.vehicleNo ?? '').isNotEmpty) trip.vehicleNo!,
              ].join(' · '),
              style: const TextStyle(color: DplColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stageChip(String stage) {
    Color c;
    String label;
    switch (stage) {
      case 'dispatched':
        c = DplColors.primary;
        label = 'Awaiting Gate Out';
        break;
      case 'gate_out':
        c = DplColors.warning;
        label = 'Enroute — Scan LECI at TATA';
        break;
      case 'tata_gate_in':
        c = DplColors.primary;
        label = 'At TATA — Scan by QRE';
        break;
      case 'tata_dock_in':
        c = DplColors.warning;
        label = 'Dock — QRE verifying';
        break;
      case 'tata_dock_out':
        c = DplColors.primary;
        label = 'Ready for Gate Out';
        break;
      case 'tata_gate_out':
        c = DplColors.success;
        label = 'Trip Complete';
        break;
      default:
        c = DplColors.textSecondary;
        label = stage;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.10),
        border: Border.all(color: c.withOpacity(0.30)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: c,
        ),
      ),
    );
  }

  Widget _stageBody(String stage, String qrToken) {
    switch (stage) {
      case 'dispatched':
        return _showQrPanel(
          qrToken,
          caption: 'Show this QR to Security at the Origin gate.',
        );
      case 'gate_out':
        return _leciScanPanel();
      case 'tata_gate_in':
        return _showQrPanel(
          qrToken,
          caption: 'Show this QR to QRE at the TATA dock.',
        );
      case 'tata_dock_in':
        return _passivePanel(
          icon: Icons.hourglass_bottom_rounded,
          title: 'QRE is verifying trolleys…',
          subtitle:
              'Wait for the QRE to record Dock Out. This screen will refresh automatically.',
        );
      case 'tata_dock_out':
        return _gateOutButton();
      case 'tata_gate_out':
        return _passivePanel(
          icon: Icons.check_circle_rounded,
          color: DplColors.success,
          title: 'Trip complete',
          subtitle:
              'All journey events recorded. You can safely leave TATA premises.',
        );
      default:
        return _passivePanel(
          icon: Icons.info_outline_rounded,
          title: 'Stage: $stage',
          subtitle: 'No driver action needed right now.',
        );
    }
  }

  Widget _showQrPanel(String qrToken, {required String caption}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        children: [
          if (qrToken.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.white,
              child: QrImageView(
                data: qrToken,
                version: QrVersions.auto,
                size: 260,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('QR unavailable — refresh to retry.'),
            ),
          const SizedBox(height: 12),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: DplColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _leciScanPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'You have exited the origin gate. When you arrive at TATA, collect the LECI paper and scan the barcode on it.',
            style: TextStyle(color: DplColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            label: const Text('Scan LECI barcode'),
            onPressed: _busy ? null : _openLeciScanner,
          ),
        ],
      ),
    );
  }

  Widget _gateOutButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'QRE has completed Dock Out. Confirm your final gate exit from TATA.',
            style: TextStyle(color: DplColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Mark TATA Gate Out'),
            onPressed: _busy ? null : _markGateOut,
          ),
        ],
      ),
    );
  }

  Widget _passivePanel({
    required IconData icon,
    required String title,
    required String subtitle,
    Color? color,
  }) {
    final c = color ?? DplColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DplColors.divider),
        boxShadow: DplShadows.card,
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: c),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: c,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: DplColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openLeciScanner() async {
    final result = await Navigator.of(context).push<_LeciResult>(
      MaterialPageRoute(builder: (_) => const _LeciScannerScreen()),
    );
    if (!mounted || result == null) return;
    await _submitLeci(result);
  }

  Future<void> _submitLeci(_LeciResult r) async {
    if (r.truckNo.isEmpty) {
      DplSnacks.error(context, 'Could not read a truck number from the LECI barcode. Please rescan.');
      return;
    }
    setState(() => _busy = true);
    final api = ref.read(dplApiServiceProvider);
    final res = await api.tataGateInTrip(
      widget.tripId,
      leciBarcode: r.raw,
      leciTruckNo: r.truckNo,
      leciNo: r.leciNo,
      leciRfid: r.rfid,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.isError) {
      final err = res.error ?? 'TATA Gate In failed';
      final isMismatch = err.toLowerCase().contains('vehicle_mismatch') ||
          err.toLowerCase().contains('mismatch');
      DplSnacks.error(
        context,
        isMismatch
            ? 'Vehicle number on LECI does not match this trip. Please verify.'
            : err,
      );
      return;
    }
    DplSnacks.success(context, 'TATA Gate In recorded.');
    await _load();
  }

  Future<void> _markGateOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Mark TATA Gate Out'),
        content: const Text(
            'This finalises the trip. Confirm you have exited the TATA gate.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final api = ref.read(dplApiServiceProvider);
    final res = await api.tataGateOutTrip(widget.tripId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.isError) {
      DplSnacks.error(context, res.error ?? 'Gate Out failed');
      return;
    }
    DplSnacks.success(context, 'Trip complete.');
    await _load();
  }
}

// ─────────────────────────────────────────────────────────────────────
// LECI scanner (full-screen) — parses TATA gate paper barcode text
// ─────────────────────────────────────────────────────────────────────

class _LeciResult {
  final String raw;
  final String leciNo;
  final String truckNo;
  final String rfid;
  const _LeciResult({
    required this.raw,
    required this.leciNo,
    required this.truckNo,
    required this.rfid,
  });
}

/// LECI paper is line-oriented text of the form:
///   RFID No: 33124163324
///   Check-in: 20.07.2026 / 12:47:06
///   Check Point: AHD01
///   Truck Number: KA-51-AK-3966
///   Driver Name: ...
///   ...
///   LECI No: 2668193S
///
/// Some scanners emit newlines, some emit spaces. We extract by regex
/// so either variant works.
_LeciResult _parseLeci(String raw) {
  final normalized = raw.replaceAll('\r', '\n');
  String pick(RegExp re) {
    final m = re.firstMatch(normalized);
    return (m?.group(1) ?? '').trim();
  }
  return _LeciResult(
    raw: raw,
    leciNo: pick(RegExp(r'LECI\s*No[:\s]+([A-Za-z0-9\-]+)', caseSensitive: false)),
    truckNo: pick(RegExp(r'Truck\s*Number[:\s]+([A-Za-z0-9\-\s]+?)(?=\s{2,}|\n|$)', caseSensitive: false)),
    rfid:   pick(RegExp(r'RFID\s*No[:\s]+([A-Za-z0-9\-]+)', caseSensitive: false)),
  );
}

class _LeciScannerScreen extends StatefulWidget {
  const _LeciScannerScreen();

  @override
  State<_LeciScannerScreen> createState() => _LeciScannerScreenState();
}

class _LeciScannerScreenState extends State<_LeciScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan LECI barcode')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (capture) {
          if (_handled) return;
          final code = capture.barcodes.firstOrNull;
          final raw = code?.rawValue ?? '';
          if (raw.isEmpty) return;
          _handled = true;
          final parsed = _parseLeci(raw);
          Navigator.of(context).pop(parsed);
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
