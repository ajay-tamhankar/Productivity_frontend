import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/master_data_models.dart';
import 'master_management_repository.dart';

class RcNumberManagementScreen extends ConsumerStatefulWidget {
  const RcNumberManagementScreen({super.key});

  @override
  ConsumerState<RcNumberManagementScreen> createState() =>
      _RcNumberManagementScreenState();
}

class _RcNumberManagementScreenState
    extends ConsumerState<RcNumberManagementScreen> {
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  String _query = '';
  String? _error;
  List<RcNumberModel> _items = const [];

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  MasterManagementRepository get _repo =>
      ref.read(masterManagementRepositoryProvider);

  String _cleanError(Object e) {
    final s = e.toString();
    return s.startsWith('Exception:') ? s.substring('Exception:'.length).trim() : s;
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final list = await _repo.listRcNumbers();
      if (!mounted) return;
      setState(() { _items = list; _isLoading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; _error = _cleanError(e); });
    }
  }

  Future<void> _wrap(Future<void> Function() action) async {
    setState(() => _isSubmitting = true);
    try { await action(); } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  List<RcNumberModel> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _items;
    return _items.where((m) =>
      m.rcNumber.toLowerCase().contains(q) ||
      m.description.toLowerCase().contains(q) ||
      m.status.toLowerCase().contains(q)).toList();
  }

  Future<void> _create() async {
    final result = await showDialog<_RCPayload>(
      context: context, barrierDismissible: false,
      builder: (_) => const _RCCreateDialog(),
    );
    if (result == null) return;
    try {
      await _wrap(() async {
        await _repo.createRcNumber(rcNumber: result.rcNumber, description: result.description);
        await _load();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RC number created successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanError(e))));
    }
  }

  Future<void> _edit(RcNumberModel item) async {
    final result = await showDialog<_RCEditPayload>(
      context: context, barrierDismissible: false,
      builder: (_) => _RCEditDialog(item: item),
    );
    if (result == null) return;
    try {
      await _wrap(() async {
        await _repo.updateRcNumber(
          id: item.id,
          rcNumber: result.rcNumber != item.rcNumber ? result.rcNumber : null,
          description: result.description != item.description ? result.description : null,
          status: result.status != item.status ? result.status : null,
        );
        await _load();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RC number updated successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanError(e))));
    }
  }

  Future<void> _delete(RcNumberModel item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete RC Number'),
        content: Text('Delete "${item.rcNumber}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB32929)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _wrap(() async { await _repo.deleteRcNumber(item.id); await _load(); });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('RC number deleted successfully.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Scaffold(
      appBar: AppBar(
        title: const Text('RC Number Management'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Add', onPressed: _create, icon: const Icon(Icons.add_circle_outline)),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFF2FFF9), Color(0xFFF7F2FF)],
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search RC number, description, status',
                ),
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2F1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD2CF)),
                  ),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFF8A2A24), fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
              ],
              if (_isLoading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 28), child: Center(child: CircularProgressIndicator()))
              else if (filtered.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2EAF6)),
                  ),
                  child: const Text('No RC numbers found.', style: TextStyle(color: Color(0xFF5D6A7A))),
                )
              else
                ...filtered.map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RCCard(item: m, onEdit: () => _edit(m), onDelete: () => _delete(m)),
                )),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        label: const Text('Add RC Number'),
        icon: const Icon(Icons.add_circle_outline),
      ),
      bottomNavigationBar: _isSubmitting ? const LinearProgressIndicator(minHeight: 2) : null,
    );
  }
}

class _RCCard extends StatelessWidget {
  final RcNumberModel item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RCCard({required this.item, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.rcNumber,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(item.description, style: const TextStyle(color: Color(0xFF5D6A7A))),
          ],
          const SizedBox(height: 4),
          Text('Status: ${item.status.isEmpty ? '-' : item.status}',
            style: const TextStyle(color: Color(0xFF5D6A7A))),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            _RCChip(icon: Icons.edit_outlined, label: 'Edit', color: const Color(0xFF127944), onTap: onEdit),
            _RCChip(icon: Icons.delete_outline, label: 'Delete', color: const Color(0xFFB32929), onTap: onDelete),
          ]),
        ],
      ),
    );
  }
}

class _RCChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RCChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

class _RCPayload {
  final String rcNumber;
  final String description;
  const _RCPayload({required this.rcNumber, required this.description});
}

class _RCCreateDialog extends StatefulWidget {
  const _RCCreateDialog();
  @override
  State<_RCCreateDialog> createState() => _RCCreateDialogState();
}

class _RCCreateDialogState extends State<_RCCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _rcCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() { _rcCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_RCPayload(rcNumber: _rcCtrl.text.trim(), description: _descCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add RC Number'),
      content: SizedBox(width: 400, child: Form(key: _formKey, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _rcCtrl,
            decoration: const InputDecoration(labelText: 'RC Number *'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'RC Number is required.' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description')),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Create')),
      ],
    );
  }
}

class _RCEditPayload {
  final String rcNumber;
  final String description;
  final String status;
  const _RCEditPayload({required this.rcNumber, required this.description, required this.status});
}

class _RCEditDialog extends StatefulWidget {
  final RcNumberModel item;
  const _RCEditDialog({required this.item});
  @override
  State<_RCEditDialog> createState() => _RCEditDialogState();
}

class _RCEditDialogState extends State<_RCEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _rcCtrl;
  late final TextEditingController _descCtrl;
  late String _status;

  @override
  void initState() {
    super.initState();
    _rcCtrl = TextEditingController(text: widget.item.rcNumber);
    _descCtrl = TextEditingController(text: widget.item.description);
    final s = widget.item.status.trim().toUpperCase();
    const allowed = {'ACTIVE', 'INACTIVE'};
    _status = allowed.contains(s) ? s : 'ACTIVE';
  }

  @override
  void dispose() { _rcCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_RCEditPayload(
      rcNumber: _rcCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      status: _status,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit RC Number'),
      content: SizedBox(width: 420, child: Form(key: _formKey, child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _rcCtrl,
            decoration: const InputDecoration(labelText: 'RC Number *'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'RC Number is required.' : null,
          ),
          const SizedBox(height: 10),
          TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: const [
              DropdownMenuItem(value: 'ACTIVE', child: Text('ACTIVE')),
              DropdownMenuItem(value: 'INACTIVE', child: Text('INACTIVE')),
            ],
            onChanged: (v) { if (v != null) setState(() => _status = v); },
          ),
        ],
      ))),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Apply Changes')),
      ],
    );
  }
}
