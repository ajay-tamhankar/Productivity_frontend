import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/production_entry_model.dart';
import '../auth/auth_provider.dart';
import 'master_data_provider.dart';
import 'production_entry_provider.dart';

class ProductionEntryScreen extends ConsumerStatefulWidget {
  const ProductionEntryScreen({super.key});

  @override
  ConsumerState<ProductionEntryScreen> createState() => _ProductionEntryScreenState();
}

class _ProductionEntryScreenState extends ConsumerState<ProductionEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  String _shift = 'A';
  String? _machineId;
  String? _itemId;
  String? _customerId;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _actualCtrl = TextEditingController();
  final _rejectCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  final Map<String, int> _rejectionReasons = {};

  bool _submittedOnce = false;
  String? _formError;
  double _itemWeightG = 0;
  double _runningHours = 0;
  double _partsPerHour = 0;
  double _weightKg = 0;

  static const _reasons = ['Scratch', 'Dent', 'Discoloration', 'Flash', 'Short Shot'];

  @override
  void initState() {
    super.initState();
    _actualCtrl.addListener(_recompute);
  }

  @override
  void dispose() {
    _actualCtrl.removeListener(_recompute);
    _actualCtrl.dispose();
    _rejectCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  int _safeInt(String v) => int.tryParse(v.trim()) ?? 0;

  DateTime? _toDate(TimeOfDay? t) {
    if (t == null) return null;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, t.hour, t.minute);
  }

  bool _isTimeValid() {
    final s = _toDate(_startTime);
    final e = _toDate(_endTime);
    if (s == null || e == null) return false;
    return e.isAfter(s);
  }

  String? _timeError() {
    if (_startTime == null || _endTime == null) {
      return 'Start Time and End Time are required.';
    }
    if (!_isTimeValid()) {
      return 'End time must be greater than Start time.';
    }
    return null;
  }

  void _recompute() {
    final controller = ref.read(productionEntryControllerProvider.notifier);
    final actual = _safeInt(_actualCtrl.text);
    if (_isTimeValid()) {
      _runningHours = controller.calculateRunningHours(_startTime!, _endTime!);
      _partsPerHour = controller.calculatePartsPerHour(actual, _runningHours);
    } else {
      _runningHours = 0;
      _partsPerHour = 0;
    }
    _weightKg = controller.calculateWeightInKGs(actual, _itemWeightG);
    if (mounted) setState(() {});
  }

  String? _reqDrop(String? v, String name) => (v == null || v.trim().isEmpty) ? '$name is required.' : null;
  String? _qty(String? v, String name) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return '$name is required.';
    if (!RegExp(r'^\d+$').hasMatch(t)) return 'Enter a valid number.';
    return null;
  }

  String _err(Object e) {
    final s = e.toString();
    return s.startsWith('Exception:') ? s.substring('Exception:'.length).trim() : s;
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
      _formError = null;
    });
    _recompute();
  }

  Future<void> _showReasonDialog() async {
    final draft = Map<String, int>.from(_rejectionReasons);
    final actual = _safeInt(_actualCtrl.text);
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            int total = 0;
            for (final v in draft.values) {
              total += v;
            }
            final invalid = total > actual;
            final maxContentHeight = MediaQuery.of(context).size.height * 0.45;
            return AlertDialog(
              title: const Text('Rejection Details'),
              content: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxContentHeight),
                child: SizedBox(
                  width: 360,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final r in _reasons)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Expanded(child: Text(r)),
                                SizedBox(
                                  width: 88,
                                  child: TextFormField(
                                    initialValue: (draft[r] ?? 0).toString(),
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                    onChanged: (v) {
                                      final p = int.tryParse(v) ?? 0;
                                      setDialog(() {
                                        if (p <= 0) {
                                          draft.remove(r);
                                        } else {
                                          draft[r] = p;
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Total: $total / Actual: $actual',
                          style: TextStyle(
                            color: invalid ? Colors.red : Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (invalid)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Rejection Quantity cannot exceed Actual Quantity.',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: invalid
                      ? null
                      : () {
                          setState(() {
                            _rejectionReasons
                              ..clear()
                              ..addAll(draft);
                            int t = 0;
                            for (final v in _rejectionReasons.values) {
                              t += v;
                            }
                            _rejectCtrl.text = '$t';
                          });
                          Navigator.pop(ctx);
                        },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submittedOnce = true;
      _formError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _formError = 'Mandatory fields must not be empty and numeric fields must be valid.');
      return;
    }
    final timeError = _timeError();
    if (timeError != null) {
      setState(() => _formError = timeError);
      return;
    }

    final actual = _safeInt(_actualCtrl.text);
    final reject = _safeInt(_rejectCtrl.text);
    if (reject > actual) {
      setState(() => _formError = 'Rejection Quantity cannot exceed Actual Quantity.');
      return;
    }

    final s = _toDate(_startTime)!;
    final e = _toDate(_endTime)!;
    final auth = ref.read(authControllerProvider).asData?.value;

    final entry = ProductionEntryModel(
      entryDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      shift: _shift,
      operatorId: auth?.id ?? 'unknown',
      machineId: _machineId!,
      itemId: _itemId!,
      customerId: _customerId!,
      ccd1Quantity: 0,
      actualQuantity: actual,
      rejectionQuantity: reject,
      startTime: s.toUtc().toIso8601String(),
      endTime: e.toUtc().toIso8601String(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      rejectionDetails: _rejectionReasons.entries
          .where((e) => e.value > 0)
          .map((e) => RejectionDetailModel(reason: e.key, quantity: e.value))
          .toList(),
    );

    await ref.read(productionEntryControllerProvider.notifier).submitEntry(entry);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(productionEntryControllerProvider, (prev, next) {
      if (!mounted) return;
      if (prev?.isLoading == true && next.hasError) {
        setState(() => _formError = _err(next.error!));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_err(next.error!))));
      }
      if (prev?.isLoading == true && next.hasValue) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Production entry submitted successfully.')));
        context.pop();
      }
    });

    final submitState = ref.watch(productionEntryControllerProvider);
    final masterData = ref.watch(masterDataControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('New Production Entry')),
      body: masterData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(_err(e))),
        data: (d) => Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF4F8FF), Color(0xFFE8FFF6), Color(0xFFE9F0FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1546A0).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -30,
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A8D78).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 920),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.50),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.8)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F3A8A).withOpacity(0.10),
                            blurRadius: 22,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: _submittedOnce
                            ? AutovalidateMode.onUserInteraction
                            : AutovalidateMode.disabled,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _HeadCard(),
                            if (_formError != null) ...[
                              const SizedBox(height: 12),
                              _ErrorBanner(message: _formError!),
                            ],
                            const SizedBox(height: 12),
                            _Section(
                              title: 'Basic Details',
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: _shift,
                                    decoration: const InputDecoration(
                                      labelText: 'Shift *',
                                      prefixIcon: Icon(Icons.schedule_outlined),
                                    ),
                                    items: const ['A', 'B', 'C']
                                        .map((s) =>
                                            DropdownMenuItem(value: s, child: Text('Shift $s')))
                                        .toList(),
                                    onChanged: (v) => setState(() => _shift = v ?? 'A'),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: _machineId,
                                    decoration: const InputDecoration(
                                      labelText: 'Machine *',
                                      prefixIcon:
                                          Icon(Icons.precision_manufacturing_outlined),
                                    ),
                                    items: d.machines
                                        .map((m) => DropdownMenuItem(
                                              value: m.id,
                                              child: Text('${m.machineNumber} - ${m.name}'),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _machineId = v),
                                    validator: (v) => _reqDrop(v, 'Machine'),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: _itemId,
                                    decoration: const InputDecoration(
                                      labelText: 'Item *',
                                      prefixIcon: Icon(Icons.inventory_2_outlined),
                                    ),
                                    items: d.items
                                        .map((i) => DropdownMenuItem(
                                              value: i.id,
                                              child: Text('${i.itemCode} - ${i.description}'),
                                            ))
                                        .toList(),
                                    onChanged: (v) {
                                      var weight = 0.0;
                                      for (final i in d.items) {
                                        if (i.id == v) {
                                          weight = i.finishWeightG;
                                          break;
                                        }
                                      }
                                      setState(() {
                                        _itemId = v;
                                        _itemWeightG = weight;
                                      });
                                      _recompute();
                                    },
                                    validator: (v) => _reqDrop(v, 'Item'),
                                  ),
                                  const SizedBox(height: 10),
                                  DropdownButtonFormField<String>(
                                    value: _customerId,
                                    decoration: const InputDecoration(
                                      labelText: 'Customer *',
                                      prefixIcon: Icon(Icons.business_outlined),
                                    ),
                                    items: d.customers
                                        .map((c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(c.name),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setState(() => _customerId = v),
                                    validator: (v) => _reqDrop(v, 'Customer'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: 'Time & Quantity',
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(52),
                                            alignment: Alignment.centerLeft,
                                          ),
                                          onPressed: () => _pickTime(true),
                                          icon: const Icon(Icons.login_outlined),
                                          label: Text(
                                            _startTime == null
                                                ? 'Start Time *'
                                                : _startTime!.format(context),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            minimumSize: const Size.fromHeight(52),
                                            alignment: Alignment.centerLeft,
                                          ),
                                          onPressed: () => _pickTime(false),
                                          icon: const Icon(Icons.logout_outlined),
                                          label: Text(
                                            _endTime == null
                                                ? 'End Time *'
                                                : _endTime!.format(context),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_submittedOnce && _timeError() != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          _timeError()!,
                                          style: const TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _actualCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Actual Quantity *',
                                      hintText: 'Enter produced units',
                                      prefixIcon: Icon(Icons.pin_outlined),
                                    ),
                                    validator: (v) => _qty(v, 'Actual Quantity'),
                                  ),
                                  const SizedBox(height: 10),
                                  TextFormField(
                                    controller: _rejectCtrl,
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly
                                    ],
                                    decoration: const InputDecoration(
                                      labelText: 'Rejection Quantity *',
                                      hintText: 'Enter rejected units',
                                      prefixIcon: Icon(Icons.warning_amber_outlined),
                                    ),
                                    validator: (v) => _qty(v, 'Rejection Quantity') ?? (() {
                                      final r = _safeInt(v ?? '');
                                      final a = _safeInt(_actualCtrl.text);
                                      return r > a
                                          ? 'Rejection Quantity cannot exceed Actual Quantity.'
                                          : null;
                                    })(),
                                  ),
                                  const SizedBox(height: 10),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: OutlinedButton.icon(
                                      onPressed: _showReasonDialog,
                                      icon: const Icon(Icons.playlist_add),
                                      label: const Text('Rejection Details'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: 'Auto Calculations',
                              child: Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _Chip(
                                    label: 'Running Hours',
                                    value: _runningHours.toStringAsFixed(2),
                                  ),
                                  _Chip(
                                    label: 'Parts / Hour',
                                    value: _partsPerHour.toStringAsFixed(2),
                                  ),
                                  _Chip(
                                    label: 'Weight (KG)',
                                    value: _weightKg.toStringAsFixed(3),
                                  ),
                                  _Chip(
                                    label: 'Item Weight (g)',
                                    value: _itemWeightG.toStringAsFixed(2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Section(
                              title: 'Notes (Optional)',
                              child: TextFormField(
                                controller: _notesCtrl,
                                maxLines: 3,
                                decoration: const InputDecoration(
                                  labelText: 'Notes',
                                  hintText: 'Any special observations',
                                  prefixIcon: Icon(Icons.notes_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF185ADB),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: submitState.isLoading ? null : _submit,
                                icon: submitState.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: Text(
                                  submitState.isLoading
                                      ? 'Submitting...'
                                      : 'Submit Entry',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadCard extends StatelessWidget {
  const _HeadCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF153A8A), Color(0xFF1965B2), Color(0xFF1B9C7A)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF153A8A).withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.factory_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Production Run Entry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fill mandatory fields, keep End Time greater than Start Time, and ensure rejection never exceeds actual quantity.',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E9F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F3A8A).withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  const _Chip({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final color = switch (label) {
      'Running Hours' => const Color(0xFF1E63D8),
      'Parts / Hour' => const Color(0xFF0E9F6E),
      'Weight (KG)' => const Color(0xFF7A4DCC),
      _ => const Color(0xFFD97706),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4C596A))),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFECEA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFB4AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB3261E)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF8F1D18), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
