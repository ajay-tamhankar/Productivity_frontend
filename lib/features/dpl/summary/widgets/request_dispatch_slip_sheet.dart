import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/design/dpl_theme.dart';
import '../../core/dpl_api_service.dart';
import '../../core/widgets/dpl_snack.dart';
import '../../models/dpl_dispatch_slip.dart';
import '../../models/dpl_production_summary.dart';
import '../providers/dispatch_slips_provider.dart';
import '../providers/production_summary_provider.dart';

/// Bottom sheet shown when Dispatch taps "Request Dispatch Slip" on a
/// summary card. Pre-fills the (machine, part) context, lets the user
/// enter a qty bounded by [DplProductionSummary.availableForDispatchQty],
/// and submits via `POST /dispatch/slips`. On success it pushes a snack
/// + invalidates the summary + slips providers so the UI reflects the
/// new bucket immediately. Returns the created slip to the caller.
class RequestDispatchSlipSheet extends ConsumerStatefulWidget {
  final DplProductionSummary bucket;

  const RequestDispatchSlipSheet({super.key, required this.bucket});

  /// Convenience launcher — pops the sheet and returns the created slip
  /// (or `null` if the user closed without submitting).
  static Future<DplDispatchSlip?> show(
    BuildContext context, {
    required DplProductionSummary bucket,
  }) {
    return showModalBottomSheet<DplDispatchSlip?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RequestDispatchSlipSheet(bucket: bucket),
    );
  }

  @override
  ConsumerState<RequestDispatchSlipSheet> createState() =>
      _RequestDispatchSlipSheetState();
}

class _RequestDispatchSlipSheetState
    extends ConsumerState<RequestDispatchSlipSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _notesCtrl;
  bool _submitting = false;
  String? _serverError;

  int get _maxQty => widget.bucket.availableForDispatchQty;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _validateQty(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty) return 'Enter a quantity.';
    final n = int.tryParse(value);
    if (n == null) return 'Enter a whole number.';
    if (n <= 0) return 'Quantity must be greater than 0.';
    if (n > _maxQty) {
      return 'Only ${NumberFormat.decimalPattern().format(_maxQty)} available.';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_maxQty <= 0) {
      setState(() {
        _serverError = 'No quantity left to dispatch for this bucket.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _serverError = null;
    });

    final qty = int.parse(_qtyCtrl.text.trim());
    final notes = _notesCtrl.text.trim();
    final svc = ref.read(dplApiServiceProvider);
    final res = await svc.createDispatchSlip(
      machineId: widget.bucket.machineId,
      partId: widget.bucket.partId,
      qty: qty,
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

    final slip = res.data;
    // Refresh production-summary + slip list + per-bucket count chips
    // so the new slip + reduced available qty + pipeline indicator all
    // show up immediately on whichever screen the user returns to.
    ref.invalidate(dplProductionSummaryProvider);
    ref.invalidate(dplDispatchSlipsProvider);
    ref.invalidate(dplBucketSlipCountsProvider);

    DplSnacks.success(
      context,
      'Slip ${slip?.slipNo ?? "created"} sent to QA.',
    );
    Navigator.of(context).pop(slip);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.decimalPattern();
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final b = widget.bucket;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: const BoxDecoration(
          color: DplColors.cardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: DplShadows.sheet,
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: DplColors.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: DplColors.primaryTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_shipping_outlined,
                          size: 18,
                          color: DplColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Request Dispatch Slip',
                                style: DplText.h3()),
                            const SizedBox(height: 2),
                            const Text(
                              'QA + PDI will review before it can ship.',
                              style: TextStyle(
                                color: DplColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Locked context block — what slip will be created for.
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DplColors.pageBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DplColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _LabelValue(label: 'Machine', value: b.machineLabel),
                        if (b.machineCode.isNotEmpty &&
                            b.machineCode != b.machineLabel)
                          _LabelValue(label: 'Code', value: b.machineCode),
                        _LabelValue(label: 'Part', value: b.partLabel),
                        if (b.customerPartNo.isNotEmpty)
                          _LabelValue(
                            label: 'Customer P/N',
                            value: b.customerPartNo,
                          ),
                        if (b.description.isNotEmpty &&
                            b.description != b.partLabel)
                          _LabelValue(
                            label: 'Description',
                            value: b.description,
                          ),
                        _LabelValue(
                          label: 'Available',
                          value: '${fmt.format(_maxQty)} '
                              '(of ${fmt.format(b.totalActualQty)})',
                          emphasised: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(7),
                    ],
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Qty for dispatch',
                      helperText: _maxQty > 0
                          ? 'Up to ${fmt.format(_maxQty)} units'
                          : 'No qty available right now',
                      prefixIcon: const Icon(Icons.inventory_2_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: _validateQty,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    maxLength: 240,
                    decoration: InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Truck #, customer ref, etc.',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  if (_serverError != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: DplColors.errorBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: DplColors.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 18,
                            color: DplColors.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _serverError!,
                              style: const TextStyle(
                                color: DplColors.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _submitting
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed:
                              (_submitting || _maxQty <= 0) ? null : _submit,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_rounded),
                          label: Text(
                            _submitting ? 'Sending…' : 'Send to QA',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LabelValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasised;
  const _LabelValue({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: DplColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: emphasised
                    ? DplColors.primaryDark
                    : DplColors.textPrimary,
                fontWeight: emphasised ? FontWeight.w800 : FontWeight.w700,
                fontSize: emphasised ? 13 : 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
