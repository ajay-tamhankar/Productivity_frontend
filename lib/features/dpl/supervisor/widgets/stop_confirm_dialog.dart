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

    // Block completion when nothing was actually produced — a
    // zero-actual "completed" item is almost always a misclick that
    // corrupts the day's report. Supervisor should either enter the
    // real qty, keep the item running, or carry the leftover forward
    // via the manager.
    final blocked = _actualQty <= 0;

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
              decoration: InputDecoration(
                labelText: 'Actual Qty',
                prefixIcon:
                    const Icon(Icons.confirmation_number_outlined),
                errorText: blocked
                    ? 'Actual qty must be at least 1 to complete.'
                    : null,
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
            if (blocked) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF92400E),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cannot complete with 0 produced. Either enter the '
                        'actual qty you ran, or close the dialog and ask '
                        'your manager to carry this item forward to the '
                        'next shift.',
                        style: TextStyle(
                          color: Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          onPressed: blocked
              ? null
              : () => Navigator.of(context).pop(
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
