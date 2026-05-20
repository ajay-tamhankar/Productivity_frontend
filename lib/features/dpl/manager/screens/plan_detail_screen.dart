import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/shimmer_skeleton.dart';
import '../../core/dpl_api_service.dart';
import '../../core/dpl_constants.dart';
import '../../models/dpl_part.dart';
import '../../models/dpl_production_plan.dart';
import '../../models/dpl_production_plan_item.dart';
import '../providers/dpl_plan_detail_provider.dart';
import '../providers/dpl_plan_list_provider.dart';
import '../widgets/dpl_manager_footer.dart';
import '../widgets/empty_state.dart';
import '../widgets/error_retry.dart';
import '../widgets/part_search_field.dart';
import '../widgets/plan_item_tile.dart';
import '../widgets/status_badge.dart';

enum _PlanMenu { edit, delete }

class DplPlanDetailScreen extends ConsumerWidget {
  final int planId;

  const DplPlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(dplPlanDetailProvider(planId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan Detail'),
        actions: [
          detail.maybeWhen(
            data: (res) {
              if (res.isError || res.data == null) {
                return const SizedBox.shrink();
              }
              return PopupMenuButton<_PlanMenu>(
                onSelected: (action) =>
                    _handleMenu(context, ref, res.data!, action),
                itemBuilder: (_) => [
                  if (DplPlanStatus.isEditable(res.data!.status))
                    const PopupMenuItem(
                      value: _PlanMenu.edit,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit header'),
                      ),
                    ),
                  if (DplPlanStatus.isDeletable(res.data!.status))
                    const PopupMenuItem(
                      value: _PlanMenu.delete,
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete plan'),
                      ),
                    ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dplPlanDetailProvider(planId));
          await ref.read(dplPlanDetailProvider(planId).future);
        },
        child: detail.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: SkeletonList(count: 5),
          ),
          error: (e, _) => ListView(
            children: [
              DplErrorRetry(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(dplPlanDetailProvider(planId)),
              ),
            ],
          ),
          data: (res) {
            if (res.isError) {
              return ListView(
                children: [
                  DplErrorRetry(
                    message: res.error ?? 'Failed to load plan.',
                    onRetry: () =>
                        ref.invalidate(dplPlanDetailProvider(planId)),
                  ),
                ],
              );
            }
            final plan = res.data!;
            return _PlanBody(plan: plan);
          },
        ),
      ),
      bottomNavigationBar: DplManagerFooter(
        aboveNav: detail.maybeWhen(
          data: (res) {
            if (res.isError || res.data == null) {
              return const SizedBox.shrink();
            }
            final plan = res.data!;
            if (!DplPlanStatus.isLockable(plan.status)) {
              return const SizedBox.shrink();
            }
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('Lock Plan'),
                    onPressed: () => _confirmLock(context, ref, plan),
                  ),
                ),
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ),
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    WidgetRef ref,
    DplProductionPlan plan,
    _PlanMenu action,
  ) async {
    switch (action) {
      case _PlanMenu.edit:
        await _showEditHeader(context, ref, plan);
        break;
      case _PlanMenu.delete:
        await _confirmDelete(context, ref, plan);
        break;
    }
  }

  Future<void> _confirmLock(
    BuildContext context,
    WidgetRef ref,
    DplProductionPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Lock Plan?'),
        content: const Text(
          'Locking prevents any further edits to this plan. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Lock'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final res = await ref.read(dplApiServiceProvider).lockPlan(plan.id);
    if (!context.mounted) return;

    if (res.isError) {
      DplSnack.error(context, res.error ?? 'Failed to lock plan.');
      return;
    }
    DplSnack.success(context, 'Plan locked.');
    ref.invalidate(dplPlanDetailProvider(planId));
    ref.invalidate(dplPlanListProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DplProductionPlan plan,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Plan?'),
        content: Text(
          'Delete the draft plan for ${plan.machineName.isEmpty ? "Machine #${plan.machineId}" : plan.machineName}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFB3261E)),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final res = await ref.read(dplApiServiceProvider).deletePlan(plan.id);
    if (!context.mounted) return;

    if (res.isError) {
      DplSnack.error(context, res.error ?? 'Failed to delete plan.');
      return;
    }
    DplSnack.success(context, 'Plan deleted.');
    ref.invalidate(dplPlanListProvider);
    if (context.canPop()) context.pop();
  }

  Future<void> _showEditHeader(
    BuildContext context,
    WidgetRef ref,
    DplProductionPlan plan,
  ) async {
    final releasedCtrl =
        TextEditingController(text: plan.planReleasedBy);
    final approvedCtrl =
        TextEditingController(text: plan.planApprovedBy);
    final remarksCtrl = TextEditingController(text: plan.remarks ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Edit Plan Header'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: releasedCtrl,
                decoration:
                    const InputDecoration(labelText: 'Plan Released By'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: approvedCtrl,
                decoration:
                    const InputDecoration(labelText: 'Plan Approved By'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: remarksCtrl,
                decoration: const InputDecoration(labelText: 'Remarks'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved != true) return;

    final res = await ref.read(dplApiServiceProvider).updatePlan(
          plan.id,
          DplUpdatePlanRequest(
            planReleasedBy: releasedCtrl.text.trim(),
            planApprovedBy: approvedCtrl.text.trim(),
            remarks: remarksCtrl.text.trim(),
          ),
        );

    if (!context.mounted) return;
    if (res.isError) {
      DplSnack.error(context, res.error ?? 'Failed to update plan.');
      return;
    }
    DplSnack.success(context, 'Plan updated.');
    ref.invalidate(dplPlanDetailProvider(planId));
  }
}

class _PlanBody extends ConsumerWidget {
  final DplProductionPlan plan;
  const _PlanBody({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = NumberFormat.decimalPattern();
    final dateFmt = DateFormat('EEEE, dd MMM yyyy');
    final pct = (plan.completionPct * 100).round();
    final canEdit = DplPlanStatus.isEditable(plan.status);
    final readOnly = DplPlanStatus.isReadOnly(plan.status);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EAF6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      plan.machineName.isEmpty
                          ? 'Machine #${plan.machineId}'
                          : plan.machineName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  DplStatusBadge(status: plan.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                dateFmt.format(plan.planDate),
                style: const TextStyle(color: Color(0xFF5D6A7A)),
              ),
              const SizedBox(height: 12),
              _kvRow('Supervisor', plan.supervisorName),
              _kvRow('Released by', plan.planReleasedBy),
              _kvRow('Approved by', plan.planApprovedBy),
              if ((plan.remarks ?? '').isNotEmpty)
                _kvRow('Remarks', plan.remarks!),
              const SizedBox(height: 12),
              Row(
                children: [
                  _bigKv('Plan', fmt.format(plan.totalPlanQty)),
                  const SizedBox(width: 16),
                  _bigKv('Actual', fmt.format(plan.totalActualQty)),
                  const SizedBox(width: 16),
                  _bigKv('Completion', '$pct%'),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: plan.completionPct,
                  minHeight: 6,
                  backgroundColor: const Color(0xFFEEF1F5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Plan Items',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            if (canEdit)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add),
                label: const Text('Add item'),
                onPressed: () => _addItem(context, ref, plan),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (plan.items.isEmpty)
          const DplEmptyState(
            icon: Icons.list_alt_outlined,
            title: 'No items yet',
            message: 'Add items to this plan to track production.',
          )
        else
          ...plan.items.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DplPlanItemTile(
                item: i,
                onTap: readOnly ? null : () => _editItem(context, ref, plan, i),
                onLongPress:
                    readOnly ? null : () => _confirmDeleteItem(context, ref, plan, i),
              ),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _kvRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF5D6A7A),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigKv(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF5D6A7A),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Future<void> _addItem(
    BuildContext context,
    WidgetRef ref,
    DplProductionPlan plan,
  ) async {
    final item = await showDialog<DplProductionPlanItem>(
      context: context,
      builder: (_) => _PlanItemDialog(
        title: 'Add item',
        defaultPlanNo: plan.items.length + 1,
        defaultSequence: plan.items.length + 1,
        machineName: plan.machineName,
      ),
    );
    if (item == null) return;

    final res = await ref
        .read(dplApiServiceProvider)
        .addPlanItem(plan.id, item);
    if (!context.mounted) return;
    if (res.isError) {
      DplSnack.error(context, res.error ?? 'Failed to add item.');
      return;
    }
    DplSnack.success(context, 'Item added.');
    ref.invalidate(dplPlanDetailProvider(plan.id));
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    DplProductionPlan plan,
    DplProductionPlanItem existing,
  ) async {
    final item = await showDialog<DplProductionPlanItem>(
      context: context,
      builder: (_) => _PlanItemDialog(
        title: 'Edit item',
        existing: existing,
        defaultPlanNo: existing.planNo,
        defaultSequence: existing.sequence,
        machineName: plan.machineName,
      ),
    );
    if (item == null) return;

    if (DplPlanStatus.inProgress == plan.status) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Plan in progress'),
          content: const Text(
              'This plan is in progress. Editing items may affect supervisor flow. Continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    final res = await ref
        .read(dplApiServiceProvider)
        .updatePlanItem(plan.id, existing.id, item);
    if (!context.mounted) return;
    if (res.isError) {
      DplSnack.error(context, res.error ?? 'Failed to update item.');
      return;
    }
    DplSnack.success(context, 'Item updated.');
    ref.invalidate(dplPlanDetailProvider(plan.id));
  }

  Future<void> _confirmDeleteItem(
    BuildContext context,
    WidgetRef ref,
    DplProductionPlan plan,
    DplProductionPlanItem item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove item #${item.planNo} from this plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB3261E),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await ref
        .read(dplApiServiceProvider)
        .deletePlanItem(plan.id, item.id);
    if (!context.mounted) return;
    if (res.isError) {
      DplSnack.error(context, res.error ?? 'Failed to delete item.');
      return;
    }
    DplSnack.success(context, 'Item deleted.');
    ref.invalidate(dplPlanDetailProvider(plan.id));
  }
}

class _PlanItemDialog extends StatefulWidget {
  final String title;
  final DplProductionPlanItem? existing;
  final int defaultPlanNo;
  final int defaultSequence;
  /// Optional — scopes the part autocomplete to a specific machine via
  /// the backend's `?machine_name=` query param.
  final String? machineName;

  const _PlanItemDialog({
    required this.title,
    required this.defaultPlanNo,
    required this.defaultSequence,
    this.existing,
    this.machineName,
  });

  @override
  State<_PlanItemDialog> createState() => _PlanItemDialogState();
}

class _PlanItemDialogState extends State<_PlanItemDialog> {
  late final TextEditingController _planNoCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _seqCtrl;
  late final TextEditingController _remarksCtrl;
  DplPart? _selectedPart;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _planNoCtrl =
        TextEditingController(text: (e?.planNo ?? widget.defaultPlanNo).toString());
    _qtyCtrl =
        TextEditingController(text: (e?.planQty ?? 0).toString());
    _seqCtrl = TextEditingController(
        text: (e?.sequence ?? widget.defaultSequence).toString());
    _remarksCtrl = TextEditingController(text: e?.remarks ?? '');
    if (e != null && e.partId > 0) {
      _selectedPart = DplPart(
        id: e.partId,
        partNumber: e.partNumber,
        description: e.partDescription,
        name: e.partName,
      );
    }
  }

  @override
  void dispose() {
    _planNoCtrl.dispose();
    _qtyCtrl.dispose();
    _seqCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final partId = _selectedPart?.id ?? 0;
    final planNo = int.tryParse(_planNoCtrl.text.trim()) ?? 0;
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final seq = int.tryParse(_seqCtrl.text.trim()) ?? 0;

    if (partId <= 0) {
      setState(() => _error = 'Please select a part.');
      return;
    }
    if (planNo <= 0) {
      setState(() => _error = 'Plan number must be greater than 0.');
      return;
    }
    if (qty <= 0) {
      setState(() => _error = 'Plan qty must be greater than 0.');
      return;
    }

    Navigator.of(context).pop(
      DplProductionPlanItem(
        id: widget.existing?.id ?? 0,
        planNo: planNo,
        partId: partId,
        partNumber: _selectedPart?.partNumber ?? '',
        partDescription: _selectedPart?.description ?? '',
        partName: _selectedPart?.name ?? '',
        planQty: qty,
        sequence: seq,
        remarks: _remarksCtrl.text.trim().isEmpty
            ? null
            : _remarksCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFECEA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFB4AA)),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFF8F1D18),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _planNoCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Plan No'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _seqCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Sequence'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DplPartSearchField(
                machineName: widget.machineName,
                initialPart: _selectedPart,
                onChanged: (p) => setState(() => _selectedPart = p),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Plan Qty'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _remarksCtrl,
                decoration:
                    const InputDecoration(labelText: 'Remarks (optional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.existing == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }
}
