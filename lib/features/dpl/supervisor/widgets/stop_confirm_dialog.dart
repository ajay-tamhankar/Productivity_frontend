import 'package:flutter/material.dart';

/// Result returned by [StopConfirmDialog].
class StopConfirmResult {
  final int actualQty;
  final String? remarks;
  const StopConfirmResult({required this.actualQty, this.remarks});
}

/// Confirmation dialog shown when the user taps STOP & COMPLETE.
/// Pre-fills `actualQty` with the latest live value; lets the user
/// tweak it; shows a green/red variance line.
class StopConfirmDialog extends StatefulWidget {
  final int planQty;
  final int initialActualQty;

  const StopConfirmDialog({
    super.key,
    required this.planQty,
    required this.initialActualQty,
  });

  @override
  State<StopConfirmDialog> createState() => _StopConfirmDialogState();
}

class _StopConfirmDialogState extends State<StopConfirmDialog> {
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _remarksCtrl;
  late int _actualQty;

  @override
  void initState() {
    super.initState();
    _actualQty = widget.initialActualQty;
    _qtyCtrl = TextEditingController(text: _actualQty.toString());
    _remarksCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _onQtyChanged(String v) {
    final n = int.tryParse(v.trim()) ?? 0;
    setState(() => _actualQty = n < 0 ? 0 : n);
  }

  @override
  Widget build(BuildContext context) {
    final variance = _actualQty - widget.planQty;
    final varianceColor = variance == 0
        ? const Color(0xFF5D6A7A)
        : (variance > 0
            ? const Color(0xFF047857)
            : const Color(0xFFB3261E));
    final varianceLabel =
        variance > 0 ? '+$variance' : variance.toString();

    return AlertDialog(
      title: const Text('Complete production?'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              onChanged: _onQtyChanged,
              decoration: const InputDecoration(
                labelText: 'Actual Qty',
                prefixIcon: Icon(Icons.confirmation_number_outlined),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD9E2EF)),
              ),
              child: Row(
                children: [
                  Text(
                    'Plan: ${widget.planQty}',
                    style: const TextStyle(
                      color: Color(0xFF5D6A7A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Actual: $_actualQty',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Variance: $varianceLabel',
                    style: TextStyle(
                      color: varianceColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _remarksCtrl,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Remarks (optional)',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            StopConfirmResult(
              actualQty: _actualQty,
              remarks: _remarksCtrl.text.trim().isEmpty
                  ? null
                  : _remarksCtrl.text.trim(),
            ),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB3261E),
          ),
          child: const Text('Stop & Complete'),
        ),
      ],
    );
  }
}
