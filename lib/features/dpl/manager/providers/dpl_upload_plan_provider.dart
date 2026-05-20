import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dpl_api_response.dart';
import '../../core/dpl_api_service.dart';
import '../../core/dpl_excel_parser.dart';
import '../../models/dpl_excel_preview.dart';
import '../../models/dpl_machine.dart';
import '../../models/dpl_part.dart';
import '../../models/dpl_production_plan.dart';
import '../../models/dpl_production_plan_item.dart';
import 'dpl_masters_provider.dart';

/// Mode toggle on the upload-plan screen.
enum DplUploadMode { excel, manual }

/// One "section" in manual-entry mode — one machine, N plan items.
class DplManualMachineDraft {
  final int machineId;
  final String machineName;
  final List<DplProductionPlanItem> items;

  const DplManualMachineDraft({
    required this.machineId,
    required this.machineName,
    this.items = const [],
  });

  int get totalPlanQty => items.fold(0, (a, i) => a + i.planQty);

  DplManualMachineDraft copyWith({
    int? machineId,
    String? machineName,
    List<DplProductionPlanItem>? items,
  }) {
    return DplManualMachineDraft(
      machineId: machineId ?? this.machineId,
      machineName: machineName ?? this.machineName,
      items: items ?? this.items,
    );
  }
}

class DplUploadPlanState {
  final DateTime planDate;
  final int? supervisorUserId;
  /// Optional pre-assigned shift — when set, every item in this
  /// submission gets pre-tagged with this shift. When null, the backend
  /// auto-derives the shift from each item's first START click.
  final int? shiftId;
  final String planReleasedBy;
  final String planApprovedBy;
  final DplUploadMode mode;
  final DplExcelPreview? excelPreview;
  final List<DplManualMachineDraft> manualDrafts;
  final bool isSubmitting;
  final String? error;

  const DplUploadPlanState({
    required this.planDate,
    this.supervisorUserId,
    this.shiftId,
    this.planReleasedBy = '',
    this.planApprovedBy = '',
    this.mode = DplUploadMode.excel,
    this.excelPreview,
    this.manualDrafts = const [],
    this.isSubmitting = false,
    this.error,
  });

  static const Object _sentinel = Object();

  DplUploadPlanState copyWith({
    DateTime? planDate,
    Object? supervisorUserId = _sentinel,
    Object? shiftId = _sentinel,
    String? planReleasedBy,
    String? planApprovedBy,
    DplUploadMode? mode,
    Object? excelPreview = _sentinel,
    List<DplManualMachineDraft>? manualDrafts,
    bool? isSubmitting,
    Object? error = _sentinel,
  }) {
    return DplUploadPlanState(
      planDate: planDate ?? this.planDate,
      supervisorUserId: identical(supervisorUserId, _sentinel)
          ? this.supervisorUserId
          : supervisorUserId as int?,
      shiftId: identical(shiftId, _sentinel)
          ? this.shiftId
          : shiftId as int?,
      planReleasedBy: planReleasedBy ?? this.planReleasedBy,
      planApprovedBy: planApprovedBy ?? this.planApprovedBy,
      mode: mode ?? this.mode,
      excelPreview: identical(excelPreview, _sentinel)
          ? this.excelPreview
          : excelPreview as DplExcelPreview?,
      manualDrafts: manualDrafts ?? this.manualDrafts,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

final dplUploadPlanControllerProvider = NotifierProvider.autoDispose<
    DplUploadPlanController, DplUploadPlanState>(
  DplUploadPlanController.new,
);

class DplUploadPlanController extends Notifier<DplUploadPlanState> {
  @override
  DplUploadPlanState build() {
    // Default = tomorrow, no supervisor yet, default released/approved strings.
    final today = DateTime.now();
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    return DplUploadPlanState(
      planDate: tomorrow,
      planReleasedBy: 'Vistar Logitek Pvt. Ltd.',
      planApprovedBy: 'Grupo Antolin India Pvt. Ltd',
    );
  }

  void setDate(DateTime d) =>
      state = state.copyWith(planDate: DateTime(d.year, d.month, d.day));

  void setSupervisor(int? id) =>
      state = state.copyWith(supervisorUserId: id);

  void setShift(int? id) => state = state.copyWith(shiftId: id);

  void setReleasedBy(String s) => state = state.copyWith(planReleasedBy: s);
  void setApprovedBy(String s) => state = state.copyWith(planApprovedBy: s);

  void setMode(DplUploadMode m) => state = state.copyWith(mode: m);

  /// Seeds the manual-entry drafts from a list of machines. Called once
  /// when the user switches to manual mode (so they see "Nexon SR",
  /// "Nexon PR", "X0 HL" instead of an empty screen).
  void seedManualDrafts(List<DplManualMachineDraft> drafts) {
    if (state.manualDrafts.isNotEmpty) return;
    state = state.copyWith(manualDrafts: drafts);
  }

  void addManualItem(int machineId, DplProductionPlanItem item) {
    final next = state.manualDrafts.map((d) {
      if (d.machineId != machineId) return d;
      final newItems = [...d.items, item];
      return d.copyWith(items: newItems);
    }).toList();
    state = state.copyWith(manualDrafts: next);
  }

  void updateManualItem(
    int machineId,
    int index,
    DplProductionPlanItem item,
  ) {
    final next = state.manualDrafts.map((d) {
      if (d.machineId != machineId) return d;
      if (index < 0 || index >= d.items.length) return d;
      final newItems = [...d.items];
      newItems[index] = item;
      return d.copyWith(items: newItems);
    }).toList();
    state = state.copyWith(manualDrafts: next);
  }

  void removeManualItem(int machineId, int index) {
    final next = state.manualDrafts.map((d) {
      if (d.machineId != machineId) return d;
      if (index < 0 || index >= d.items.length) return d;
      final newItems = [...d.items]..removeAt(index);
      return d.copyWith(items: newItems);
    }).toList();
    state = state.copyWith(manualDrafts: next);
  }

  void updateExcelRow(int machineId, int rowIndex, DplExcelPlanRow updated) {
    final preview = state.excelPreview;
    if (preview == null) return;
    final next = preview.machines.map((m) {
      if (m.machineId != machineId) return m;
      if (rowIndex < 0 || rowIndex >= m.rows.length) return m;
      final newRows = [...m.rows];
      newRows[rowIndex] = updated;
      return DplExcelMachineSection(
        machineId: m.machineId,
        machineName: m.machineName,
        rows: newRows,
      );
    }).toList();
    state = state.copyWith(
      excelPreview: DplExcelPreview(
        machines: next,
        warnings: preview.warnings,
      ),
    );
  }

  /// Parses the picked Excel file **on the client** and stores a preview.
  ///
  /// The backend's `upload-excel` endpoint exists but doesn't currently
  /// understand the company's "Daily Production Loading Chart" template
  /// (one machine per sheet, custom header). Parsing in Flutter using
  /// the existing `excel` package keeps the preview UI flow identical
  /// while making the parser easy to evolve alongside the template.
  ///
  /// Steps:
  ///   1. Load machines (cached) + parts master (one-shot, generous page).
  ///   2. Run [DplExcelParser.parse] against the bytes.
  ///   3. Store the resulting preview on state.
  Future<DplApiResponse<DplExcelPreview>> pickAndUploadExcel({
    required Uint8List bytes,
    required String filename,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    final svc = ref.read(dplApiServiceProvider);

    // 1a. Machines — prefer the cached provider, fall back to a fresh fetch.
    List<DplMachine> machines = const [];
    final cached = ref.read(dplMachinesProvider).asData?.value;
    if (cached != null && cached.isOk && cached.data != null) {
      machines = cached.data!;
    } else {
      final mRes = await svc.getMachines();
      if (mRes.isOk) machines = mRes.data ?? const [];
    }

    // 1b. Parts — fetch in parallel per machine using `?machine_name=`.
    // This keeps the payload tight (each machine only returns its own
    // parts) and improves match accuracy, since `description` codes like
    // "102ZX" can repeat across machines.
    final List<DplPart> parts = [];
    if (machines.isEmpty) {
      // No machine master yet — fall back to a single broad fetch.
      final pRes = await svc.getParts(page: 1, limit: 500);
      if (pRes.isOk) parts.addAll(pRes.data?.items ?? const <DplPart>[]);
    } else {
      final responses = await Future.wait(
        machines.map(
          (m) => svc.getParts(machineName: m.name, page: 1, limit: 500),
        ),
      );
      for (final r in responses) {
        if (r.isOk) parts.addAll(r.data?.items ?? const <DplPart>[]);
      }
    }

    // 2. Parse.
    DplExcelPreview preview;
    try {
      preview = DplExcelParser.parse(
        bytes: bytes,
        machines: machines,
        parts: parts,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Could not read Excel file: $e',
      );
      return DplApiResponse.error('Could not read Excel file: $e');
    }

    // 3. Store + return.
    state = state.copyWith(
      isSubmitting: false,
      excelPreview: preview,
      mode: DplUploadMode.excel,
    );
    return DplApiResponse.ok(preview);
  }

  /// Validates the current form + posts `POST /plans`.
  ///
  /// Returns either the created plans (success) or an error.
  Future<DplApiResponse<List<DplProductionPlan>>> submit() async {
    final supervisorId = state.supervisorUserId;
    if (supervisorId == null) {
      final r = DplApiResponse<List<DplProductionPlan>>.error(
        'Please select a supervisor.',
      );
      state = state.copyWith(error: r.error);
      return r;
    }

    final machines = <DplCreatePlanForMachine>[];

    if (state.mode == DplUploadMode.excel) {
      final preview = state.excelPreview;
      if (preview == null || preview.machines.isEmpty) {
        final r = DplApiResponse<List<DplProductionPlan>>.error(
          'Please upload and preview an Excel file first.',
        );
        state = state.copyWith(error: r.error);
        return r;
      }
      for (final section in preview.machines) {
        final validRows =
            section.rows.where((r) => r.partId != null && r.planQty > 0).toList();
        if (validRows.isEmpty) continue;
        machines.add(
          DplCreatePlanForMachine(
            machineId: section.machineId,
            items: validRows
                .map((r) => DplProductionPlanItem(
                      id: 0,
                      planNo: r.planNo,
                      partId: r.partId!,
                      planQty: r.planQty,
                      sequence: r.sequence,
                    ))
                .toList(),
          ),
        );
      }
    } else {
      for (final d in state.manualDrafts) {
        final valid =
            d.items.where((i) => i.partId > 0 && i.planQty > 0).toList();
        if (valid.isEmpty) continue;
        machines.add(
          DplCreatePlanForMachine(machineId: d.machineId, items: valid),
        );
      }
    }

    if (machines.isEmpty) {
      final r = DplApiResponse<List<DplProductionPlan>>.error(
        'At least one machine must have at least one valid item.',
      );
      state = state.copyWith(error: r.error);
      return r;
    }

    final req = DplCreatePlansRequest(
      planDate: state.planDate,
      supervisorUserId: supervisorId,
      planReleasedBy: state.planReleasedBy,
      planApprovedBy: state.planApprovedBy,
      shiftId: state.shiftId,
      machines: machines,
    );

    state = state.copyWith(isSubmitting: true, error: null);
    final res = await ref.read(dplApiServiceProvider).createPlans(req);
    state = state.copyWith(
      isSubmitting: false,
      error: res.isError ? res.error : null,
    );
    return res;
  }
}
