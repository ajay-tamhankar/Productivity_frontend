import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Tappable, read-only input that opens a native date picker.
class DplDatePickerField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;
  final DateTime? lastDate;
  final IconData icon;
  final bool enabled;

  const DplDatePickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.lastDate,
    this.icon = Icons.calendar_today_outlined,
    this.enabled = true,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? DateTime.now(),
      firstDate: firstDate ?? DateTime(2000),
      lastDate: lastDate ?? DateTime(2100),
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy');
    final text = value == null ? 'Select date' : fmt.format(value!);

    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: enabled
            ? IconButton(
                icon: const Icon(Icons.edit_calendar_outlined),
                onPressed: () => _pick(context),
              )
            : null,
      ),
      child: GestureDetector(
        onTap: enabled ? () => _pick(context) : null,
        behavior: HitTestBehavior.opaque,
        child: Text(
          text,
          style: TextStyle(
            color: value == null
                ? Theme.of(context).colorScheme.onSurfaceVariant
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
