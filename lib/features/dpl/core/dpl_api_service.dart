import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/dpl_dashboard_summary.dart';
import '../models/dpl_downtime_event.dart';
import '../models/dpl_downtime_event_detail.dart';
import '../models/dpl_downtime_reason.dart';
import '../models/dpl_excel_preview.dart';
import '../models/dpl_machine.dart';
import '../models/dpl_manpower_log.dart';
import '../models/dpl_organization.dart';
import '../models/dpl_monthly_chart.dart';
import '../models/dpl_part.dart';
import '../models/dpl_production_plan.dart';
import '../models/dpl_production_summary.dart';
import '../models/dpl_production_plan_item.dart';
import '../models/dpl_reports.dart';
import '../models/dpl_shift.dart';
import '../models/dpl_shift_summary.dart';
import '../models/dpl_start_stop.dart';
import '../models/dpl_supervisor.dart';
import '../models/dpl_supervisor_plan_detail.dart';
import '../models/dpl_carry_candidate.dart';
import '../models/dpl_dispatch_slip.dart';
import '../models/dpl_identity.dart';
import '../models/dpl_plant.dart';
import '../models/dpl_item_pause.dart';
import '../models/dpl_supervisor_today.dart';
import '../models/dpl_trolley_photo.dart';
import 'dpl_api_client.dart';
import 'dpl_api_response.dart';
import 'dpl_constants.dart';
import 'dpl_error_mapper.dart';

/// Single, central wrapper around every DPL endpoint.
///
/// All public methods return [DplApiResponse]. Raw exceptions are caught
/// and converted to `DplApiResponse.error(...)` so callers never need a
/// try/catch.
class DplApiService {
  final Dio _dio;

  DplApiService(this._dio);

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Unwraps the `{ success, data, error }` envelope and parses [data]
  /// through [fromJson]. Tolerates raw shapes too (some servers return
  /// arrays/objects without the envelope).
  Future<DplApiResponse<T>> _send<T>(
    Future<Response<dynamic>> Function() request, {
    required String fallback,
    T Function(dynamic data)? fromJson,
  }) async {
    try {
      final response = await request();
      final body = response.data;

      if (body is Map) {
        final map = Map<String, dynamic>.from(body);
        if (map.containsKey('success')) {
          final ok = map['success'] == true;
          if (!ok) {
            return DplApiResponse.error(
              map['error']?.toString() ?? fallback,
              code: map['code']?.toString(),
              statusCode: response.statusCode,
            );
          }
          final data = map['data'];
          if (fromJson == null) return DplApiResponse.ok(null as T?);
          return DplApiResponse.ok(fromJson(data));
        }
      }

      // No envelope — pass the raw body to fromJson.
      if (fromJson == null) return DplApiResponse.ok(null as T?);
      return DplApiResponse.ok(fromJson(body));
    } on DioException catch (e) {
      return DplErrorMapper.fromDio<T>(e, fallback: fallback);
    } catch (e) {
      return DplErrorMapper.fromObject<T>(e, fallback: fallback);
    }
  }

  String _ymd(DateTime d) =>
      DateFormat('yyyy-MM-dd').format(d);

  Map<String, dynamic> _cleanQuery(Map<String, dynamic> raw) {
    raw.removeWhere((_, v) => v == null);
    return raw;
  }

  // ---------------------------------------------------------------------------
  // 1) Auth
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<DplLoginResult>> login(
    String email,
    String password,
  ) {
    return _send<DplLoginResult>(
      () => _dio.post(
        DplPaths.authLogin,
        data: {'email': email, 'password': password},
      ),
      fallback: 'Login failed. Please try again.',
      fromJson: (data) => DplLoginResult.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : const {},
      ),
    );
  }

  Future<DplApiResponse<DplUserProfile>> me() {
    return _send<DplUserProfile>(
      () => _dio.get(DplPaths.authMe),
      fallback: 'Unable to load profile.',
      fromJson: (data) => DplUserProfile.fromJson(
        data is Map ? Map<String, dynamic>.from(data) : const {},
      ),
    );
  }

  Future<DplApiResponse<void>> logout() {
    return _send<void>(
      () => _dio.post(DplPaths.authLogout),
      fallback: 'Logout failed.',
    );
  }

  Future<DplApiResponse<void>> changePassword(
    String oldPassword,
    String newPassword,
  ) {
    return _send<void>(
      () => _dio.post(
        DplPaths.authChangePassword,
        data: {
          'old_password': oldPassword,
          'new_password': newPassword,
        },
      ),
      fallback: 'Failed to change password.',
    );
  }

  // ---------------------------------------------------------------------------
  // 2) Dashboard
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<DplDashboardSummary>> getDashboard(DateTime date) {
    return _send<DplDashboardSummary>(
      () => _dio.get(
        DplPaths.dashboard,
        queryParameters: {'date': _ymd(date)},
      ),
      fallback: 'Failed to load dashboard.',
      fromJson: (data) {
        if (data is Map) {
          return DplDashboardSummary.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        return DplDashboardSummary.empty(date);
      },
    );
  }

  Future<DplApiResponse<List<DplAlert>>> getAlerts() {
    return _send<List<DplAlert>>(
      () => _dio.get(DplPaths.alerts),
      fallback: 'Failed to load alerts.',
      fromJson: (data) {
        // Backend shape:
        //   {
        //     "date": "...",
        //     "plans_behind":     [ {machine_name, plan_qty, actual_qty, ...} ],
        //     "active_downtimes": [ {machine_name, reason_name, duration_minutes, ...} ],
        //     "totals": { "plans_behind": N, "active_downtimes": M }
        //   }
        // We flatten both buckets into a single list of [DplAlert].
        final alerts = <DplAlert>[];

        void appendBucket(
          dynamic raw,
          DplAlert Function(Map<String, dynamic>) build,
        ) {
          if (raw is! List) return;
          for (final entry in raw) {
            if (entry is Map) {
              alerts.add(build(Map<String, dynamic>.from(entry)));
            }
          }
        }

        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          appendBucket(map['plans_behind'] ?? map['plansBehind'],
              DplAlert.fromPlanBehind);
          appendBucket(map['active_downtimes'] ?? map['activeDowntimes'],
              DplAlert.fromActiveDowntime);
          // Generic shape fallback if the backend ever ships a flat list.
          appendBucket(map['items'] ?? map['alerts'], DplAlert.fromJson);
        } else if (data is List) {
          appendBucket(data, DplAlert.fromJson);
        }

        return alerts;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 3) Masters — Machines
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<List<DplMachine>>> getMachines() {
    return _send<List<DplMachine>>(
      () => _dio.get(DplPaths.machines),
      fallback: 'Failed to load machines.',
      fromJson: _listFrom<DplMachine>(DplMachine.fromJson),
    );
  }

  Future<DplApiResponse<DplMachine>> createMachine(DplMachine m) {
    return _send<DplMachine>(
      () => _dio.post(DplPaths.machines, data: m.toCreateJson()),
      fallback: 'Failed to create machine.',
      fromJson: _oneFrom<DplMachine>(DplMachine.fromJson),
    );
  }

  Future<DplApiResponse<DplMachine>> updateMachine(int id, DplMachine m) {
    return _send<DplMachine>(
      () => _dio.put(DplPaths.machineById(id), data: m.toUpdateJson()),
      fallback: 'Failed to update machine.',
      fromJson: _oneFrom<DplMachine>(DplMachine.fromJson),
    );
  }

  Future<DplApiResponse<void>> deleteMachine(int id) {
    return _send<void>(
      () => _dio.delete(DplPaths.machineById(id)),
      fallback: 'Failed to delete machine.',
    );
  }

  // ---------------------------------------------------------------------------
  // 4) Masters — Parts
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<DplPagedResult<DplPart>>> getParts({
    String? q,
    String? machineName,
    int page = 1,
    int limit = 20,
  }) {
    return _send<DplPagedResult<DplPart>>(
      () => _dio.get(
        DplPaths.parts,
        queryParameters: _cleanQuery({
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (machineName != null && machineName.trim().isNotEmpty)
            'machine_name': machineName.trim(),
          'page': page,
          'limit': limit,
        }),
      ),
      fallback: 'Failed to load parts.',
      fromJson: (data) {
        // Real backend shape:
        //   { "parts": [...], "pagination": {page, limit, total, totalPages} }
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);

          // Find the items list under any of the common keys.
          List<dynamic>? rawItems;
          for (final key in const ['parts', 'items', 'results', 'data']) {
            final v = map[key];
            if (v is List) {
              rawItems = v;
              break;
            }
          }

          if (rawItems != null) {
            final items = rawItems
                .whereType<Map>()
                .map((e) => DplPart.fromJson(Map<String, dynamic>.from(e)))
                .toList();

            // Pagination may be at root OR nested under `pagination`.
            Map<String, dynamic> p;
            final nested = map['pagination'];
            if (nested is Map) {
              p = Map<String, dynamic>.from(nested);
            } else {
              p = map;
            }

            int parseInt(dynamic v, int fallback) {
              if (v is int) return v;
              if (v is double) return v.toInt();
              return int.tryParse(v?.toString() ?? '') ?? fallback;
            }

            return DplPagedResult<DplPart>(
              items: items,
              page: parseInt(p['page'], page),
              limit: parseInt(p['limit'], limit),
              total: parseInt(p['total'], items.length),
            );
          }
        }
        if (data is List) {
          final items = data
              .whereType<Map>()
              .map((e) => DplPart.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return DplPagedResult<DplPart>(
            items: items,
            page: page,
            limit: limit,
            total: items.length,
          );
        }
        return DplPagedResult<DplPart>.empty();
      },
    );
  }

  Future<DplApiResponse<DplPart>> createPart(DplPart p) {
    return _send<DplPart>(
      () => _dio.post(DplPaths.parts, data: p.toJsonForWrite()),
      fallback: 'Failed to create part.',
      fromJson: _oneFrom<DplPart>(DplPart.fromJson),
    );
  }

  Future<DplApiResponse<DplPart>> updatePart(int id, DplPart p) {
    return _send<DplPart>(
      () => _dio.put(DplPaths.partById(id), data: p.toJsonForWrite()),
      fallback: 'Failed to update part.',
      fromJson: _oneFrom<DplPart>(DplPart.fromJson),
    );
  }

  Future<DplApiResponse<void>> deletePart(int id) {
    return _send<void>(
      () => _dio.delete(DplPaths.partById(id)),
      fallback: 'Failed to delete part.',
    );
  }

  // ---------------------------------------------------------------------------
  // 5) Masters — Supervisors
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<List<DplSupervisor>>> getSupervisors() {
    return _send<List<DplSupervisor>>(
      () => _dio.get(DplPaths.supervisors),
      fallback: 'Failed to load supervisors.',
      fromJson: _listFrom<DplSupervisor>(DplSupervisor.fromJson),
    );
  }

  // ---------------------------------------------------------------------------
  // 6) Masters — Downtime Reasons
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<List<DplDowntimeReason>>> getDowntimeReasons() {
    return _send<List<DplDowntimeReason>>(
      () => _dio.get(DplPaths.downtimeReasons),
      fallback: 'Failed to load downtime reasons.',
      fromJson: _listFrom<DplDowntimeReason>(DplDowntimeReason.fromJson),
    );
  }

  Future<DplApiResponse<DplDowntimeReason>> createDowntimeReason(
    DplDowntimeReason r,
  ) {
    return _send<DplDowntimeReason>(
      () => _dio.post(DplPaths.downtimeReasons, data: r.toJsonForWrite()),
      fallback: 'Failed to create downtime reason.',
      fromJson: _oneFrom<DplDowntimeReason>(DplDowntimeReason.fromJson),
    );
  }

  Future<DplApiResponse<DplDowntimeReason>> updateDowntimeReason(
    int id,
    DplDowntimeReason r,
  ) {
    return _send<DplDowntimeReason>(
      () => _dio.put(
        DplPaths.downtimeReasonById(id),
        data: r.toJsonForWrite(),
      ),
      fallback: 'Failed to update downtime reason.',
      fromJson: _oneFrom<DplDowntimeReason>(DplDowntimeReason.fromJson),
    );
  }

  Future<DplApiResponse<void>> deleteDowntimeReason(int id) {
    return _send<void>(
      () => _dio.delete(DplPaths.downtimeReasonById(id)),
      fallback: 'Failed to delete downtime reason.',
    );
  }

  // ---------------------------------------------------------------------------
  // 7) Plans
  // ---------------------------------------------------------------------------

  /// Uploads an Excel file's [bytes] under the given [filename].
  ///
  /// We take bytes + name (not a `dart:io.File`) so this works identically
  /// on web (where file_picker returns bytes) and on mobile/desktop.
  Future<DplApiResponse<DplExcelPreview>> uploadExcel({
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
        ),
      });
      return _send<DplExcelPreview>(
        () => _dio.post(DplPaths.plansUploadExcel, data: formData),
        fallback: 'Failed to upload Excel.',
        fromJson: (data) {
          if (data is Map) {
            return DplExcelPreview.fromJson(Map<String, dynamic>.from(data));
          }
          if (data is List) {
            // Backend returned the rows directly (no envelope).
            return DplExcelPreview.fromRows(data);
          }
          return const DplExcelPreview(machines: [], warnings: []);
        },
      );
    } catch (e) {
      return DplErrorMapper.fromObject<DplExcelPreview>(
        e,
        fallback: 'Failed to upload Excel.',
      );
    }
  }

  Future<DplApiResponse<List<DplProductionPlan>>> createPlans(
    DplCreatePlansRequest req,
  ) {
    return _send<List<DplProductionPlan>>(
      () => _dio.post(DplPaths.plans, data: req.toJson()),
      fallback: 'Failed to submit plan.',
      fromJson: (data) {
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => DplProductionPlan.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        if (data is Map) {
          final m = Map<String, dynamic>.from(data);
          final raw = m['plans'] ?? m['items'];
          if (raw is List) {
            return raw
                .whereType<Map>()
                .map((e) => DplProductionPlan.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .toList();
          }
          // Single plan as response
          return [DplProductionPlan.fromJson(m)];
        }
        return const [];
      },
    );
  }

  Future<DplApiResponse<List<DplProductionPlan>>> listPlans({
    DateTime? date,
    DateTime? from,
    DateTime? to,
    int? machineId,
    int? supervisorUserId,
    String? status,
  }) {
    return _send<List<DplProductionPlan>>(
      () => _dio.get(
        DplPaths.plans,
        queryParameters: _cleanQuery({
          if (date != null) 'date': _ymd(date),
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'machine_id': ?machineId,
          'supervisor_user_id': ?supervisorUserId,
          if (status != null && status.isNotEmpty) 'status': status,
        }),
      ),
      fallback: 'Failed to load plans.',
      fromJson: _listFrom<DplProductionPlan>(DplProductionPlan.fromJson),
    );
  }

  Future<DplApiResponse<DplProductionPlan>> getPlan(int id) {
    return _send<DplProductionPlan>(
      () => _dio.get(DplPaths.planById(id)),
      fallback: 'Failed to load plan.',
      fromJson: _oneFrom<DplProductionPlan>(DplProductionPlan.fromJson),
    );
  }

  Future<DplApiResponse<DplProductionPlan>> updatePlan(
    int id,
    DplUpdatePlanRequest req,
  ) {
    return _send<DplProductionPlan>(
      () => _dio.put(DplPaths.planById(id), data: req.toJson()),
      fallback: 'Failed to update plan.',
      fromJson: _oneFrom<DplProductionPlan>(DplProductionPlan.fromJson),
    );
  }

  Future<DplApiResponse<void>> deletePlan(int id) {
    return _send<void>(
      () => _dio.delete(DplPaths.planById(id)),
      fallback: 'Failed to delete plan.',
    );
  }

  Future<DplApiResponse<DplProductionPlan>> lockPlan(int id) {
    return _send<DplProductionPlan>(
      () => _dio.post(DplPaths.planLock(id)),
      fallback: 'Failed to lock plan.',
      fromJson: _oneFrom<DplProductionPlan>(DplProductionPlan.fromJson),
    );
  }

  /// `POST /manager/plans/:id/change-status` — manager moves a plan to
  /// any of the 5 statuses. Both [status] and [reason] are mandatory.
  Future<DplApiResponse<DplProductionPlan>> changePlanStatus(
    int planId, {
    required String status,
    required String reason,
  }) {
    return _send<DplProductionPlan>(
      () => _dio.post(
        DplPaths.planChangeStatus(planId),
        data: {'status': status, 'reason': reason},
      ),
      fallback: 'Failed to change plan status.',
      fromJson: _oneFrom<DplProductionPlan>(DplProductionPlan.fromJson),
    );
  }

  /// `POST /manager/plans/:planId/items/:itemId/change-status` — manager
  /// overrides an item's status (pending / in_progress / completed).
  /// Both [status] and [reason] are mandatory; mirrors the plan-level
  /// change-status contract.
  Future<DplApiResponse<DplProductionPlanItem>> changePlanItemStatus(
    int planId,
    int itemId, {
    required String status,
    required String reason,
  }) {
    return _send<DplProductionPlanItem>(
      () => _dio.post(
        DplPaths.planItemChangeStatus(planId, itemId),
        data: {'status': status, 'reason': reason},
      ),
      fallback: 'Failed to change item status.',
      fromJson:
          _oneFrom<DplProductionPlanItem>(DplProductionPlanItem.fromJson),
    );
  }

  /// `GET /manager/plans/carry-forward-candidates` — items from past
  /// submitted plans that still have leftover qty and haven't been
  /// carried forward yet. Drives the Upload Plan screen's auto-fill
  /// section.
  ///
  /// [forDate] is sent as `YYYY-MM-DD`; the server defaults to today
  /// in the plant timezone when omitted.
  Future<DplApiResponse<List<DplCarryCandidate>>> getCarryForwardCandidates({
    required int machineId,
    DateTime? forDate,
  }) {
    return _send<List<DplCarryCandidate>>(
      () => _dio.get(
        DplPaths.carryForwardCandidates,
        queryParameters: _cleanQuery({
          'machine_id': machineId,
          if (forDate != null) 'for_date': _ymd(forDate),
        }),
      ),
      fallback: 'Failed to load carry-forward candidates.',
      fromJson: (data) {
        if (data is Map) {
          final raw = data['candidates'];
          if (raw is List) {
            return raw
                .whereType<Map>()
                .map((e) => DplCarryCandidate.fromJson(
                      Map<String, dynamic>.from(e),
                    ))
                .toList();
          }
        }
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => DplCarryCandidate.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
        }
        return const <DplCarryCandidate>[];
      },
    );
  }

  /// `POST /manager/plans/:planId/items/:itemId/carry-forward` — move
  /// the leftover quantity of a partially-complete item into a NEW
  /// item assigned to [shiftId]. The source item is closed (status =
  /// completed) unless [completeSource] is false.
  ///
  /// [planQty] defaults to `(item.planQty - item.actualQty)` on the
  /// server when omitted from the body.
  Future<DplApiResponse<DplProductionPlanItem>> carryForwardItem(
    int planId,
    int itemId, {
    required int shiftId,
    int? planQty,
    bool completeSource = true,
  }) {
    return _send<DplProductionPlanItem>(
      () => _dio.post(
        DplPaths.planItemCarryForward(planId, itemId),
        data: {
          'shift_id': shiftId,
          'plan_qty': ?planQty,
          'complete_source': completeSource,
        },
      ),
      fallback: 'Failed to carry item forward.',
      fromJson:
          _oneFrom<DplProductionPlanItem>(DplProductionPlanItem.fromJson),
    );
  }

  /// `GET /manager/plans/:id/pauses` — manager-side audit of every
  /// item pause on a plan.
  Future<DplApiResponse<List<DplItemPause>>> getManagerPlanPauses(
    int planId,
  ) {
    return _send<List<DplItemPause>>(
      () => _dio.get(DplPaths.managerPlanPauses(planId)),
      fallback: 'Failed to load pauses.',
      fromJson: _listFrom<DplItemPause>(DplItemPause.fromJson),
    );
  }

  /// `GET /manager/plans/:id/items/:itemId/pauses` — audit per item.
  Future<DplApiResponse<List<DplItemPause>>> getManagerItemPauses(
    int planId,
    int itemId,
  ) {
    return _send<List<DplItemPause>>(
      () => _dio.get(DplPaths.managerPlanItemPauses(planId, itemId)),
      fallback: 'Failed to load pauses.',
      fromJson: _listFrom<DplItemPause>(DplItemPause.fromJson),
    );
  }

  Future<DplApiResponse<DplProductionPlanItem>> addPlanItem(
    int planId,
    DplProductionPlanItem item,
  ) {
    return _send<DplProductionPlanItem>(
      () => _dio.post(
        DplPaths.planItems(planId),
        data: item.toCreateJson(),
      ),
      fallback: 'Failed to add item.',
      fromJson:
          _oneFrom<DplProductionPlanItem>(DplProductionPlanItem.fromJson),
    );
  }

  Future<DplApiResponse<DplProductionPlanItem>> updatePlanItem(
    int planId,
    int itemId,
    DplProductionPlanItem item,
  ) {
    return _send<DplProductionPlanItem>(
      () => _dio.put(
        DplPaths.planItemById(planId, itemId),
        data: item.toUpdateJson(),
      ),
      fallback: 'Failed to update item.',
      fromJson:
          _oneFrom<DplProductionPlanItem>(DplProductionPlanItem.fromJson),
    );
  }

  Future<DplApiResponse<void>> deletePlanItem(int planId, int itemId) {
    return _send<void>(
      () => _dio.delete(DplPaths.planItemById(planId, itemId)),
      fallback: 'Failed to delete item.',
    );
  }

  // ---------------------------------------------------------------------------
  // 8) Reports
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<DplPlanVsActualReport>> reportPlanVsActual({
    DateTime? from,
    DateTime? to,
    int? machineId,
    int? shiftId,
    List<String>? groupBy,
  }) {
    return _send<DplPlanVsActualReport>(
      () => _dio.get(
        DplPaths.reportPlanVsActual,
        queryParameters: _cleanQuery({
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'machine_id': ?machineId,
          'shift_id': ?shiftId,
          if (groupBy != null && groupBy.isNotEmpty)
            'group_by': groupBy.join(','),
        }),
      ),
      fallback: 'Failed to load report.',
      fromJson: (data) {
        if (data is Map) {
          return DplPlanVsActualReport.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        if (data is List) {
          return DplPlanVsActualReport.fromJson({'rows': data});
        }
        return DplPlanVsActualReport.empty();
      },
    );
  }

  /// `GET /manager/reports/downtime/events` — flat list of every closed
  /// downtime occurrence in the requested window, enriched with machine,
  /// shift, supervisor, reason + category, and remarks. Mirrors the
  /// per-event "Details" sheet of the Excel export. Sorted newest-first
  /// by the backend. Same filter shape as [reportDowntime].
  Future<DplApiResponse<List<DplDowntimeEventDetail>>> listDowntimeEvents({
    DateTime? from,
    DateTime? to,
    int? machineId,
    int? shiftId,
  }) {
    return _send<List<DplDowntimeEventDetail>>(
      () => _dio.get(
        DplPaths.reportDowntimeEvents,
        queryParameters: _cleanQuery({
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'machine_id': ?machineId,
          'shift_id': ?shiftId,
        }),
      ),
      fallback: 'Failed to load downtime events.',
      fromJson: (data) {
        List<dynamic>? raw;
        if (data is List) {
          raw = data;
        } else if (data is Map) {
          for (final key in const ['events', 'items', 'data', 'rows']) {
            final v = data[key];
            if (v is List) {
              raw = v;
              break;
            }
          }
        }
        if (raw == null) return const <DplDowntimeEventDetail>[];
        return raw
            .whereType<Map>()
            .map((e) =>
                DplDowntimeEventDetail.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  Future<DplApiResponse<DplDowntimeReport>> reportDowntime({
    DateTime? from,
    DateTime? to,
    int? machineId,
    int? shiftId,
    List<String>? groupBy,
  }) {
    return _send<DplDowntimeReport>(
      () => _dio.get(
        DplPaths.reportDowntime,
        queryParameters: _cleanQuery({
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'machine_id': ?machineId,
          'shift_id': ?shiftId,
          if (groupBy != null && groupBy.isNotEmpty)
            'group_by': groupBy.join(','),
        }),
      ),
      fallback: 'Failed to load downtime report.',
      fromJson: (data) {
        if (data is Map) {
          return DplDowntimeReport.fromJson(Map<String, dynamic>.from(data));
        }
        if (data is List) {
          return DplDowntimeReport.fromJson({'rows': data});
        }
        return DplDowntimeReport.empty();
      },
    );
  }

  Future<DplApiResponse<DplSupervisorPerformanceReport>>
      reportSupervisorPerformance({
    DateTime? from,
    DateTime? to,
    int? machineId,
  }) {
    return _send<DplSupervisorPerformanceReport>(
      () => _dio.get(
        DplPaths.reportSupervisorPerformance,
        queryParameters: _cleanQuery({
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'machine_id': ?machineId,
        }),
      ),
      fallback: 'Failed to load supervisor performance.',
      fromJson: (data) {
        if (data is Map) {
          return DplSupervisorPerformanceReport.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        if (data is List) {
          return DplSupervisorPerformanceReport.fromJson({'rows': data});
        }
        return DplSupervisorPerformanceReport.empty();
      },
    );
  }

  Future<DplApiResponse<DplPartWiseReport>> reportPartWise({
    DateTime? from,
    DateTime? to,
    int? machineId,
  }) {
    return _send<DplPartWiseReport>(
      () => _dio.get(
        DplPaths.reportPartWise,
        queryParameters: _cleanQuery({
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'machine_id': ?machineId,
        }),
      ),
      fallback: 'Failed to load part-wise report.',
      fromJson: (data) {
        if (data is Map) {
          return DplPartWiseReport.fromJson(Map<String, dynamic>.from(data));
        }
        if (data is List) {
          return DplPartWiseReport.fromJson({'rows': data});
        }
        return DplPartWiseReport.empty();
      },
    );
  }

  /// Downloads a report as bytes. The caller is responsible for saving /
  /// sharing the file (use `saveReportBytes` from the existing reports
  /// feature, which is what this app already does).
  Future<DplApiResponse<Uint8List>> exportReportBytes({
    required String type,
    required String format,
    DateTime? from,
    DateTime? to,
    int? machineId,
  }) async {
    try {
      final response = await _dio.get<List<int>>(
        DplPaths.reportExport,
        queryParameters: _cleanQuery({
          'type': type,
          'format': format,
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'machine_id': ?machineId,
        }),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        return DplApiResponse.error('Empty file received from server.');
      }
      return DplApiResponse.ok(Uint8List.fromList(data));
    } on DioException catch (e) {
      return DplErrorMapper.fromDio<Uint8List>(
        e,
        fallback: 'Failed to export report.',
      );
    } catch (e) {
      return DplErrorMapper.fromObject<Uint8List>(
        e,
        fallback: 'Failed to export report.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // 9) Shifts master
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<List<DplShift>>> getShifts({
    bool includeInactive = false,
  }) {
    return _send<List<DplShift>>(
      () => _dio.get(
        DplPaths.shifts,
        queryParameters: _cleanQuery({
          if (includeInactive) 'include_inactive': 'true',
        }),
      ),
      fallback: 'Failed to load shifts.',
      fromJson: _listFrom<DplShift>(DplShift.fromJson),
    );
  }

  Future<DplApiResponse<DplShift>> createShift(DplShift s) {
    return _send<DplShift>(
      () => _dio.post(DplPaths.shifts, data: s.toCreateJson()),
      fallback: 'Failed to create shift.',
      fromJson: _oneFrom<DplShift>(DplShift.fromJson),
    );
  }

  Future<DplApiResponse<DplShift>> updateShift(int id, DplShift s) {
    return _send<DplShift>(
      () => _dio.put(DplPaths.shiftById(id), data: s.toUpdateJson()),
      fallback: 'Failed to update shift.',
      fromJson: _oneFrom<DplShift>(DplShift.fromJson),
    );
  }

  Future<DplApiResponse<void>> deleteShift(int id) {
    return _send<void>(
      () => _dio.delete(DplPaths.shiftById(id)),
      fallback: 'Failed to delete shift.',
    );
  }

  // ---------------------------------------------------------------------------
  // 10) Manpower master
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<List<DplManpowerLog>>> getManpower({
    DateTime? from,
    DateTime? to,
    int? shiftId,
    int? machineId,
  }) {
    return _send<List<DplManpowerLog>>(
      () => _dio.get(
        DplPaths.manpower,
        queryParameters: _cleanQuery({
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'shift_id': ?shiftId,
          'machine_id': ?machineId,
        }),
      ),
      fallback: 'Failed to load manpower.',
      fromJson: _listFrom<DplManpowerLog>(DplManpowerLog.fromJson),
    );
  }

  Future<DplApiResponse<DplManpowerLog>> createManpower(DplManpowerLog m) {
    return _send<DplManpowerLog>(
      () => _dio.post(DplPaths.manpower, data: m.toCreateJson()),
      fallback: 'Failed to create manpower entry.',
      fromJson: _oneFrom<DplManpowerLog>(DplManpowerLog.fromJson),
    );
  }

  Future<DplApiResponse<DplManpowerLog>> updateManpower(
    int id,
    int headcount,
  ) {
    return _send<DplManpowerLog>(
      () => _dio.put(
        DplPaths.manpowerById(id),
        data: {'headcount': headcount},
      ),
      fallback: 'Failed to update headcount.',
      fromJson: _oneFrom<DplManpowerLog>(DplManpowerLog.fromJson),
    );
  }

  Future<DplApiResponse<void>> deleteManpower(int id) {
    return _send<void>(
      () => _dio.delete(DplPaths.manpowerById(id)),
      fallback: 'Failed to delete manpower entry.',
    );
  }

  /// Supervisor side — idempotent bulk upsert of today's manpower entries.
  Future<DplApiResponse<List<DplManpowerLog>>> supervisorPostManpowerToday(
    List<DplManpowerLog> entries,
  ) {
    return _send<List<DplManpowerLog>>(
      () => _dio.post(
        DplPaths.supervisorManpowerToday,
        data: entries.map((e) => e.toCreateJson()).toList(),
      ),
      fallback: 'Failed to save manpower.',
      fromJson: _listFrom<DplManpowerLog>(DplManpowerLog.fromJson),
    );
  }

  // ---------------------------------------------------------------------------
  // 11) Monthly DPL chart (composite report)
  // ---------------------------------------------------------------------------

  Future<DplApiResponse<DplMonthlyChart>> reportDplChart({
    required DateTime from,
    required DateTime to,
  }) {
    return _send<DplMonthlyChart>(
      () => _dio.get(
        DplPaths.reportDplChart,
        queryParameters: {'from': _ymd(from), 'to': _ymd(to)},
      ),
      fallback: 'Failed to load monthly chart.',
      fromJson: (data) {
        if (data is Map) {
          return DplMonthlyChart.fromJson(Map<String, dynamic>.from(data));
        }
        return DplMonthlyChart.empty(from, to);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 12) Identity verification (selfie gate)
  // ---------------------------------------------------------------------------

  /// `GET /supervisor/identity/status` — is the supervisor currently
  /// verified, and until when.
  Future<DplApiResponse<DplIdentityStatus>> getIdentityStatus() {
    return _send<DplIdentityStatus>(
      () => _dio.get(DplPaths.supervisorIdentityStatus),
      fallback: 'Failed to load identity status.',
      fromJson: (data) {
        if (data is Map) {
          return DplIdentityStatus.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        // Defensive default — treat as "not verified" when the shape
        // is unexpected. Forces the gate to prompt for a fresh selfie.
        return const DplIdentityStatus(
          required: true,
          verified: false,
          verifiedForCurrentShift: false,
        );
      },
    );
  }

  /// `POST /supervisor/identity/verify` — multipart upload of a selfie.
  ///
  /// [context] must be one of `DplIdentityContext.*` values. [planId]
  /// and [planItemId] are optional but recommended so the audit row
  /// records exactly what the supervisor was about to do.
  Future<DplApiResponse<DplIdentityVerification>> verifyIdentity({
    required Uint8List bytes,
    required String filename,
    required String context,
    int? planId,
    int? planItemId,
  }) async {
    try {
      final form = FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: filename),
        'context': context,
        'plan_id': ?planId,
        'plan_item_id': ?planItemId,
      });
      return _send<DplIdentityVerification>(
        () => _dio.post(DplPaths.supervisorIdentityVerify, data: form),
        fallback: 'Failed to verify identity.',
        fromJson: (data) {
          if (data is Map) {
            return DplIdentityVerification.fromJson(
              Map<String, dynamic>.from(data),
            );
          }
          throw const FormatException('Expected object response.');
        },
      );
    } catch (e) {
      return DplErrorMapper.fromObject<DplIdentityVerification>(
        e,
        fallback: 'Failed to verify identity.',
      );
    }
  }

  /// `GET /supervisor/identity/:id/photo` — raw image bytes. Supervisor
  /// can only read their own.
  Future<DplApiResponse<Uint8List>> getSupervisorIdentityPhoto(int id) async {
    try {
      final response = await _dio.get<List<int>>(
        DplPaths.supervisorIdentityPhoto(id),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        return DplApiResponse.error('Empty photo response.');
      }
      return DplApiResponse.ok(Uint8List.fromList(data));
    } on DioException catch (e) {
      return DplErrorMapper.fromDio<Uint8List>(
        e,
        fallback: 'Failed to load photo.',
      );
    } catch (e) {
      return DplErrorMapper.fromObject<Uint8List>(
        e,
        fallback: 'Failed to load photo.',
      );
    }
  }

  /// `GET /manager/identity-verifications` — paginated audit log.
  Future<DplApiResponse<DplPagedResult<DplIdentityVerification>>>
      listIdentityVerifications({
    int? supervisorId,
    int? shiftId,
    DateTime? from,
    DateTime? to,
    String? context,
    bool? flagged,
    int page = 1,
    int limit = 20,
  }) {
    return _send<DplPagedResult<DplIdentityVerification>>(
      () => _dio.get(
        DplPaths.managerIdentityVerifications,
        queryParameters: _cleanQuery({
          'supervisor_id': ?supervisorId,
          'shift_id': ?shiftId,
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          if (context != null && context.isNotEmpty) 'context': context,
          'flagged': ?flagged,
          'page': page,
          'limit': limit,
        }),
      ),
      fallback: 'Failed to load audit log.',
      fromJson: (data) {
        int parseInt(dynamic v, int fb) {
          if (v is int) return v;
          if (v is double) return v.toInt();
          return int.tryParse(v?.toString() ?? '') ?? fb;
        }

        List<DplIdentityVerification> parseList(List raw) => raw
            .whereType<Map>()
            .map((e) => DplIdentityVerification.fromJson(
                  Map<String, dynamic>.from(e),
                ))
            .toList();

        // Server may return a bare array, or a map with items + pagination.
        if (data is List) {
          final items = parseList(data);
          return DplPagedResult<DplIdentityVerification>(
            items: items,
            page: page,
            limit: limit,
            total: items.length,
          );
        }
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          List<dynamic>? raw;
          for (final key in const [
            'items',
            'identity_verifications',
            'identityVerifications',
            'verifications',
            'data',
            'rows',
            'results',
          ]) {
            final v = map[key];
            if (v is List) {
              raw = v;
              break;
            }
          }
          if (raw != null) {
            final items = parseList(raw);
            final nested = map['pagination'];
            final p =
                nested is Map ? Map<String, dynamic>.from(nested) : map;
            return DplPagedResult<DplIdentityVerification>(
              items: items,
              page: parseInt(p['page'], page),
              limit: parseInt(p['limit'], limit),
              total: parseInt(p['total'], items.length),
            );
          }
        }
        return DplPagedResult<DplIdentityVerification>.empty();
      },
    );
  }

  /// `GET /manager/identity-verifications/:id/photo` — manager view of a
  /// specific supervisor's verification photo.
  Future<DplApiResponse<Uint8List>> getManagerIdentityPhoto(int id) async {
    try {
      final response = await _dio.get<List<int>>(
        DplPaths.managerIdentityPhoto(id),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        return DplApiResponse.error('Empty photo response.');
      }
      return DplApiResponse.ok(Uint8List.fromList(data));
    } on DioException catch (e) {
      return DplErrorMapper.fromDio<Uint8List>(
        e,
        fallback: 'Failed to load photo.',
      );
    } catch (e) {
      return DplErrorMapper.fromObject<Uint8List>(
        e,
        fallback: 'Failed to load photo.',
      );
    }
  }

  /// `POST /manager/identity-verifications/:id/flag` — manager flags a
  /// verification as suspicious.
  Future<DplApiResponse<DplIdentityVerification>> flagIdentityVerification(
    int id,
    String reason,
  ) {
    return _send<DplIdentityVerification>(
      () => _dio.post(
        DplPaths.managerIdentityFlag(id),
        data: {'reason': reason},
      ),
      fallback: 'Failed to flag verification.',
      fromJson: (data) {
        if (data is Map) {
          return DplIdentityVerification.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        throw const FormatException('Expected object response.');
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 13) Supervisor (Phase 2)
  // ---------------------------------------------------------------------------

  /// `GET /supervisor/today` — supervisor's plans for current shift date.
  Future<DplApiResponse<SupervisorTodayResponse>> supervisorToday() {
    return _send<SupervisorTodayResponse>(
      () => _dio.get(DplPaths.supervisorToday),
      fallback: 'Failed to load today\'s plans.',
      fromJson: (data) {
        if (data is Map) {
          return SupervisorTodayResponse.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        return SupervisorTodayResponse.empty(DateTime.now());
      },
    );
  }

  /// `GET /supervisor/plans/:id` — full plan + active downtime + history.
  Future<DplApiResponse<DplSupervisorPlanDetail>> supervisorGetPlan(int id) {
    return _send<DplSupervisorPlanDetail>(
      () => _dio.get(DplPaths.supervisorPlan(id)),
      fallback: 'Failed to load plan.',
      fromJson: (data) {
        if (data is Map) {
          return DplSupervisorPlanDetail.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        throw const FormatException('Expected object response for plan.');
      },
    );
  }

  /// `POST /supervisor/plans/:planId/items/:itemId/start` — begin production.
  Future<DplApiResponse<StartItemResponse>> startItem(
    int planId,
    int itemId,
  ) {
    return _send<StartItemResponse>(
      () => _dio.post(DplPaths.supervisorItemStart(planId, itemId)),
      fallback: 'Failed to start item.',
      fromJson: (data) {
        if (data is Map) {
          return StartItemResponse.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        throw const FormatException('Expected object response for start.');
      },
    );
  }

  /// `POST /supervisor/plans/:planId/items/:itemId/stop` — finish production.
  ///
  /// [trolleyPhotoId] is required by the backend when the trolley-photo
  /// gate is enabled (`DPL_TROLLEY_PHOTO_REQUIRED=true`). Upload the
  /// photo via [uploadTrolleyPhoto] first, then pass the returned `id`.
  Future<DplApiResponse<StopItemResponse>> stopItem(
    int planId,
    int itemId, {
    required int actualQty,
    String? remarks,
    int? trolleyPhotoId,
  }) {
    return _send<StopItemResponse>(
      () => _dio.post(
        DplPaths.supervisorItemStop(planId, itemId),
        data: {
          'actual_qty': actualQty,
          if (remarks != null && remarks.trim().isNotEmpty)
            'remarks': remarks.trim(),
          'trolley_photo_id': ?trolleyPhotoId,
        },
      ),
      fallback: 'Failed to stop item.',
      fromJson: (data) {
        if (data is Map) {
          return StopItemResponse.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        throw const FormatException('Expected object response for stop.');
      },
    );
  }

  /// `PATCH /supervisor/plans/:planId/items/:itemId/actual` — debounced
  /// in-flight quantity updates while production is running.
  Future<DplApiResponse<void>> updateActualQty(
    int planId,
    int itemId,
    int actualQty,
  ) {
    return _send<void>(
      () => _dio.patch(
        DplPaths.supervisorItemActual(planId, itemId),
        data: {'actual_qty': actualQty},
      ),
      fallback: 'Failed to update actual quantity.',
    );
  }

  /// `POST /supervisor/plans/:planId/downtime/start` — open a downtime.
  ///
  /// [machineId] is required by the backend even though [planId] is in
  /// the URL.
  Future<DplApiResponse<DplDowntimeEvent>> startDowntime({
    required int planId,
    required int machineId,
    required int reasonId,
    int? planItemId,
    String? remarks,
  }) {
    return _send<DplDowntimeEvent>(
      () => _dio.post(
        DplPaths.supervisorDowntimeStart(planId),
        data: {
          'machine_id': machineId,
          'reason_id': reasonId,
          'plan_item_id': ?planItemId,
          if (remarks != null && remarks.trim().isNotEmpty)
            'remarks': remarks.trim(),
        },
      ),
      fallback: 'Failed to start downtime.',
      fromJson: (data) {
        if (data is Map) {
          return DplDowntimeEvent.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        throw const FormatException('Expected object response for downtime.');
      },
    );
  }

  /// `POST /supervisor/downtime/:downtimeId/resume` — close an active downtime.
  Future<DplApiResponse<DplDowntimeEvent>> resumeDowntime(int downtimeId) {
    return _send<DplDowntimeEvent>(
      () => _dio.post(DplPaths.supervisorDowntimeResume(downtimeId)),
      fallback: 'Failed to resume from downtime.',
      fromJson: (data) {
        if (data is Map) {
          return DplDowntimeEvent.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        throw const FormatException('Expected object response for resume.');
      },
    );
  }

  /// `GET /supervisor/plans/:planId/downtimes` — downtime history for a plan.
  Future<DplApiResponse<List<DplDowntimeEvent>>> listPlanDowntimes(int planId) {
    return _send<List<DplDowntimeEvent>>(
      () => _dio.get(DplPaths.supervisorPlanDowntimes(planId)),
      fallback: 'Failed to load downtimes.',
      fromJson: _listFrom<DplDowntimeEvent>(DplDowntimeEvent.fromJson),
    );
  }

  // ---------------------------------------------------------------------------
  // Item pauses — parallel to machine downtimes, scoped to one plan item.
  // ---------------------------------------------------------------------------

  /// `POST /supervisor/plans/:planId/items/:itemId/pause` — opens a
  /// pause on a single in-progress item. [reasonText] is required;
  /// [reasonId] optionally links to a downtime-reason master row.
  Future<DplApiResponse<DplItemPause>> pauseItem(
    int planId,
    int itemId, {
    required String reasonText,
    int? reasonId,
    DateTime? expectedResumeAt,
  }) {
    return _send<DplItemPause>(
      () => _dio.post(
        DplPaths.supervisorItemPause(planId, itemId),
        data: {
          'reason_text': reasonText,
          'reason_id': ?reasonId,
          if (expectedResumeAt != null)
            'expected_resume_at':
                expectedResumeAt.toUtc().toIso8601String(),
        },
      ),
      fallback: 'Failed to pause item.',
      fromJson: _oneFrom<DplItemPause>(DplItemPause.fromJson),
    );
  }

  /// `POST /supervisor/plans/:planId/items/:itemId/resume` — closes the
  /// current pause on an item. Returns the canonical duration and the
  /// item's running total of paused minutes.
  Future<DplApiResponse<DplItemResumeResult>> resumeItem(
    int planId,
    int itemId,
  ) {
    return _send<DplItemResumeResult>(
      () => _dio.post(DplPaths.supervisorItemResume(planId, itemId)),
      fallback: 'Failed to resume item.',
      fromJson: _oneFrom<DplItemResumeResult>(DplItemResumeResult.fromJson),
    );
  }

  /// `GET /supervisor/plans/:planId/pauses` — all pauses for a plan.
  Future<DplApiResponse<List<DplItemPause>>> getSupervisorPlanPauses(
    int planId,
  ) {
    return _send<List<DplItemPause>>(
      () => _dio.get(DplPaths.supervisorPlanPauses(planId)),
      fallback: 'Failed to load pauses.',
      fromJson: _listFrom<DplItemPause>(DplItemPause.fromJson),
    );
  }

  /// `GET /supervisor/plans/:planId/items/:itemId/pauses` — pauses for a
  /// single item.
  Future<DplApiResponse<List<DplItemPause>>> getSupervisorItemPauses(
    int planId,
    int itemId,
  ) {
    return _send<List<DplItemPause>>(
      () => _dio.get(DplPaths.supervisorItemPauses(planId, itemId)),
      fallback: 'Failed to load pauses.',
      fromJson: _listFrom<DplItemPause>(DplItemPause.fromJson),
    );
  }

  /// `GET /supervisor/shift/summary?date=` — end-of-shift roll-up.
  Future<DplApiResponse<DplShiftSummary>> shiftSummary(DateTime date) {
    return _send<DplShiftSummary>(
      () => _dio.get(
        DplPaths.supervisorShiftSummary,
        queryParameters: {'date': _ymd(date)},
      ),
      fallback: 'Failed to load shift summary.',
      fromJson: (data) {
        if (data is Map) {
          return DplShiftSummary.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        return DplShiftSummary.empty(date);
      },
    );
  }

  /// `POST /supervisor/shift/submit` — lock today's production.
  Future<DplApiResponse<DplShiftSubmitResult>> submitShift(
    DateTime date, {
    String? remarks,
  }) {
    return _send<DplShiftSubmitResult>(
      () => _dio.post(
        DplPaths.supervisorShiftSubmit,
        data: {
          'date': _ymd(date),
          if (remarks != null && remarks.trim().isNotEmpty)
            'remarks': remarks.trim(),
        },
      ),
      fallback: 'Failed to submit shift.',
      fromJson: (data) {
        if (data is Map) {
          return DplShiftSubmitResult.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        throw const FormatException('Expected object response for submit.');
      },
    );
  }

  /// `GET /supervisor/downtime-reasons` — reasons available to the
  /// supervisor (may include only active ones; backend-defined).
  Future<DplApiResponse<List<DplDowntimeReason>>>
      supervisorDowntimeReasons() {
    return _send<List<DplDowntimeReason>>(
      () => _dio.get(DplPaths.supervisorDowntimeReasons),
      fallback: 'Failed to load downtime reasons.',
      fromJson: _listFrom<DplDowntimeReason>(DplDowntimeReason.fromJson),
    );
  }

  // ---------------------------------------------------------------------------
  // 14) Trolley photo (gate before STOP)
  // ---------------------------------------------------------------------------

  /// `POST /supervisor/plans/:planId/items/:itemId/trolley-photo` —
  /// multipart upload of the photo a supervisor must capture before
  /// stopping a running item. Returns the persisted photo row; pass
  /// its `id` to [stopItem] within the server's freshness window
  /// (default 15 minutes).
  Future<DplApiResponse<DplTrolleyPhoto>> uploadTrolleyPhoto({
    required int planId,
    required int itemId,
    required Uint8List bytes,
    required String filename,
    String? remarks,
  }) async {
    try {
      final form = FormData.fromMap({
        'photo': MultipartFile.fromBytes(bytes, filename: filename),
        if (remarks != null && remarks.trim().isNotEmpty)
          'remarks': remarks.trim(),
      });
      return _send<DplTrolleyPhoto>(
        () => _dio.post(
          DplPaths.supervisorItemTrolleyPhoto(planId, itemId),
          data: form,
        ),
        fallback: 'Failed to upload trolley photo.',
        fromJson: (data) {
          if (data is Map) {
            return DplTrolleyPhoto.fromJson(Map<String, dynamic>.from(data));
          }
          throw const FormatException(
            'Expected object response for trolley photo.',
          );
        },
      );
    } catch (e) {
      return DplErrorMapper.fromObject<DplTrolleyPhoto>(
        e,
        fallback: 'Failed to upload trolley photo.',
      );
    }
  }

  /// `GET /supervisor/trolley-photos/:id/image` — raw image bytes. The
  /// supervisor who uploaded the photo (and managers) can read it.
  Future<DplApiResponse<Uint8List>> getSupervisorTrolleyPhotoBytes(
    int id,
  ) async {
    try {
      final response = await _dio.get<List<int>>(
        DplPaths.supervisorTrolleyPhotoImage(id),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        return DplApiResponse.error('Empty trolley photo response.');
      }
      return DplApiResponse.ok(Uint8List.fromList(data));
    } on DioException catch (e) {
      return DplErrorMapper.fromDio<Uint8List>(
        e,
        fallback: 'Failed to load trolley photo.',
      );
    } catch (e) {
      return DplErrorMapper.fromObject<Uint8List>(
        e,
        fallback: 'Failed to load trolley photo.',
      );
    }
  }

  /// `GET /manager/trolley-photos` — paginated manager-side audit
  /// log of every trolley photo captured at STOP time.
  Future<DplApiResponse<DplPagedResult<DplTrolleyPhoto>>>
      listManagerTrolleyPhotos({
    int? planId,
    int? planItemId,
    int? supervisorId,
    int? machineId,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int limit = 20,
  }) {
    return _send<DplPagedResult<DplTrolleyPhoto>>(
      () => _dio.get(
        DplPaths.managerTrolleyPhotos,
        queryParameters: _cleanQuery({
          'plan_id': ?planId,
          'plan_item_id': ?planItemId,
          'supervisor_id': ?supervisorId,
          'machine_id': ?machineId,
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'page': page,
          'limit': limit,
        }),
      ),
      fallback: 'Failed to load trolley photo audit.',
      fromJson: (data) {
        int parseInt(dynamic v, int fb) {
          if (v is int) return v;
          if (v is double) return v.toInt();
          return int.tryParse(v?.toString() ?? '') ?? fb;
        }

        List<DplTrolleyPhoto> parseList(List raw) => raw
            .whereType<Map>()
            .map((e) =>
                DplTrolleyPhoto.fromJson(Map<String, dynamic>.from(e)))
            .toList();

        if (data is List) {
          final items = parseList(data);
          return DplPagedResult<DplTrolleyPhoto>(
            items: items,
            page: page,
            limit: limit,
            total: items.length,
          );
        }
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          List<dynamic>? raw;
          for (final key in const [
            'photos',
            'trolley_photos',
            'trolleyPhotos',
            'items',
            'data',
            'rows',
            'results',
          ]) {
            final v = map[key];
            if (v is List) {
              raw = v;
              break;
            }
          }
          if (raw != null) {
            final items = parseList(raw);
            final nested = map['pagination'];
            final p =
                nested is Map ? Map<String, dynamic>.from(nested) : map;
            return DplPagedResult<DplTrolleyPhoto>(
              items: items,
              page: parseInt(p['page'], page),
              limit: parseInt(p['limit'], limit),
              total: parseInt(p['total'], items.length),
            );
          }
        }
        return DplPagedResult<DplTrolleyPhoto>.empty();
      },
    );
  }

  /// `GET /manager/active-downtimes` — every currently open downtime
  /// across all plans, sorted newest-first. Drives the manager-side
  /// red sticky banner.
  Future<DplApiResponse<List<ActiveDowntime>>> listManagerActiveDowntimes({
    int? machineId,
  }) {
    return _send<List<ActiveDowntime>>(
      () => _dio.get(
        DplPaths.managerActiveDowntimes,
        queryParameters: _cleanQuery({
          'machine_id': ?machineId,
        }),
      ),
      fallback: 'Failed to load active downtimes.',
      fromJson: (data) {
        List<dynamic>? raw;
        if (data is List) {
          raw = data;
        } else if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          for (final key in const [
            'downtimes',
            'active_downtimes',
            'activeDowntimes',
            'items',
            'data',
            'rows',
          ]) {
            final v = map[key];
            if (v is List) {
              raw = v;
              break;
            }
          }
        }
        if (raw == null) return const <ActiveDowntime>[];
        return raw
            .whereType<Map>()
            .map((e) => ActiveDowntime.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      },
    );
  }

  /// `POST /manager/downtime/:downtimeId/close` — manager-scoped
  /// recovery action that force-closes an orphaned active downtime
  /// (e.g. a supervisor logged off without resuming, leaving the red
  /// banner stuck). [reason] is optional context that gets persisted on
  /// the closed event. [organizationId] is sent in the body because the
  /// backend's audit-log writer can't derive it from the JWT here and
  /// otherwise 500s with `DplAuditLog.organization_id cannot be null`.
  /// Returns the now-closed event so callers can double-check
  /// `end_time` / `status` if they need to.
  Future<DplApiResponse<DplDowntimeEvent>> managerCloseDowntime(
    int downtimeId, {
    String? reason,
    int? organizationId,
  }) {
    return _send<DplDowntimeEvent>(
      () => _dio.post(
        DplPaths.managerDowntimeClose(downtimeId),
        data: {
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
          'organization_id': ?organizationId,
        },
      ),
      fallback: 'Failed to close downtime.',
      fromJson: (data) {
        if (data is Map) {
          return DplDowntimeEvent.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        throw const FormatException(
          'Expected object response for close downtime.',
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Production summary — aggregate of `total_actual_qty` per (machine,
  // part) bucket. Shared between Manager and the downstream Dispatch /
  // QA / PDI viewers; the backend gates access by JWT role.
  // ---------------------------------------------------------------------------

  /// `GET /manager/production-summary` — paginated, searchable,
  /// filterable rollup of every (machine, part) bucket the active
  /// organization has ever planned for.
  ///
  /// All filter / sort args are optional; passing none returns the
  /// first page of every bucket sorted by `last_produced_at desc`.
  Future<DplApiResponse<DplProductionSummaryPage>> listProductionSummary({
    String? plantCode,
    int? machineId,
    int? partId,
    String? q,
    DateTime? from,
    DateTime? to,
    bool? onlyProduced,
    String? sort,
    String? order,
    int? page,
    int? limit,
  }) {
    return _send<DplProductionSummaryPage>(
      () => _dio.get(
        DplPaths.productionSummary,
        queryParameters: _cleanQuery({
          if (plantCode != null && plantCode.isNotEmpty)
            'plant_code': plantCode,
          'machine_id': ?machineId,
          'part_id': ?partId,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          if (onlyProduced == true) 'only_produced': 'true',
          if (sort != null && sort.isNotEmpty) 'sort': sort,
          if (order != null && order.isNotEmpty) 'order': order,
          'page': ?page,
          'limit': ?limit,
        }),
      ),
      fallback: 'Failed to load production summary.',
      fromJson: (data) {
        if (data is Map) {
          return DplProductionSummaryPage.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        if (data is List) {
          // Bare-array shape — no pagination / totals envelope.
          final items = data
              .whereType<Map>()
              .map((e) => DplProductionSummary.fromJson(
                    Map<String, dynamic>.from(e),
                  ))
              .toList();
          return DplProductionSummaryPage(
            items: items,
            page: 1,
            limit: items.length,
            total: items.length,
            totalPages: items.isEmpty ? 0 : 1,
            totals: const DplProductionSummaryTotals(),
          );
        }
        return DplProductionSummaryPage.empty();
      },
    );
  }

  /// `GET /manager/production-summary/one?machine_id=&part_id=` —
  /// fetches a single bucket for a (machine, part) pair the user picked
  /// from a dropdown. Returns `null` when the backend responds 404.
  Future<DplApiResponse<DplProductionSummary?>> getProductionSummaryOne({
    required int machineId,
    required int partId,
  }) {
    return _send<DplProductionSummary?>(
      () => _dio.get(
        DplPaths.productionSummaryOne,
        queryParameters: _cleanQuery({
          'machine_id': machineId,
          'part_id': partId,
        }),
      ),
      fallback: 'Failed to load production summary entry.',
      fromJson: (data) {
        if (data is Map) {
          return DplProductionSummary.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        return null;
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Plants — hardcoded 3-plant mapping (Nexon EV / TML PV / MG Motors).
  // Backend serves a fixed array from a config file; promote to a DB
  // table later if admins ever need to edit the mapping.
  // ---------------------------------------------------------------------------

  /// `GET /plants` — returns the three plants with the machines each
  /// owns. Cached on the FE side because the list is effectively
  /// static for v1.
  Future<DplApiResponse<List<DplPlant>>> listPlants() {
    return _send<List<DplPlant>>(
      () => _dio.get(DplPaths.plants),
      fallback: 'Failed to load plants.',
      fromJson: (data) {
        if (data is List) {
          return data
              .whereType<Map>()
              .map((e) => DplPlant.fromJson(Map<String, dynamic>.from(e)))
              .toList(growable: false);
        }
        return const <DplPlant>[];
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Dispatch slips — Dispatch → QA → PDI three-step approval pipeline.
  // The slip carries an HMAC-signed QR payload on PDI approval that gate
  // staff can scan from the printed paper. Role gating is server-side.
  // ---------------------------------------------------------------------------

  /// `POST /dispatch/slips` — Dispatch creates a new slip request for
  /// [qty] units of [partId] off [machineId]. Backend enforces
  /// `qty <= total_actual − sum(non-rejected slips)` and returns
  /// `INSUFFICIENT_QTY` if violated.
  /// `POST /dispatch/slips` — multi-item slip creation.
  ///
  /// As of PR 3 the slip body carries `plant_code`, optional
  /// `vehicle_no`, and a non-empty `items[]` array of
  /// `(machine_id, part_id, qty)` triplets. Server validates that every
  /// item's machine belongs to the chosen plant, sums duplicate
  /// (machine, part) entries before the availability check, signs the
  /// QR payload at insert time, and returns the hydrated slip.
  ///
  /// Errors:
  ///   * 400 `INVALID_PLANT_CODE` — unknown plant
  ///   * 400 `INVALID_PLANT_MACHINE` — item's machine isn't in plant
  ///   * 400 `EMPTY_ITEMS` — items[] is empty
  ///   * 409 `INSUFFICIENT_QTY` — item.qty > bucket.available
  Future<DplApiResponse<DplDispatchSlip>> createDispatchSlip({
    required String plantCode,
    required List<DispatchSlipItemRequest> items,
    String? vehicleNo,
    String? notes,
  }) {
    return _send<DplDispatchSlip>(
      () => _dio.post(
        DplPaths.dispatchSlips,
        data: {
          'plant_code': plantCode,
          if (vehicleNo != null && vehicleNo.trim().isNotEmpty)
            'vehicle_no': vehicleNo.trim(),
          if (notes != null && notes.trim().isNotEmpty)
            'notes': notes.trim(),
          'items': items.map((i) => i.toJson()).toList(growable: false),
        },
      ),
      fallback: 'Failed to create dispatch slip.',
      fromJson: _oneDispatchSlip,
    );
  }

  /// `GET /dispatch/slips` — paginated list, server-side role-filtered.
  /// QA inbox: `?status=pending_qa`. PDI inbox: `?status=pending_pdi`.
  /// Dispatch defaults to their own slips across every status.
  Future<DplApiResponse<DplDispatchSlipPage>> listDispatchSlips({
    String? status,
    int? machineId,
    int? partId,
    String? q,
    DateTime? from,
    DateTime? to,
    int? page,
    int? limit,
  }) {
    return _send<DplDispatchSlipPage>(
      () => _dio.get(
        DplPaths.dispatchSlips,
        queryParameters: _cleanQuery({
          if (status != null && status.isNotEmpty) 'status': status,
          'machine_id': ?machineId,
          'part_id': ?partId,
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (from != null) 'from': _ymd(from),
          if (to != null) 'to': _ymd(to),
          'page': ?page,
          'limit': ?limit,
        }),
      ),
      fallback: 'Failed to load dispatch slips.',
      fromJson: (data) {
        if (data is Map) {
          return DplDispatchSlipPage.fromJson(Map<String, dynamic>.from(data));
        }
        if (data is List) {
          final items = data
              .whereType<Map>()
              .map((e) => DplDispatchSlip.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          return DplDispatchSlipPage(
            items: items,
            page: 1,
            limit: items.length,
            total: items.length,
            totalPages: items.isEmpty ? 0 : 1,
            totals: const DplDispatchSlipTotals(),
          );
        }
        return DplDispatchSlipPage.empty();
      },
    );
  }

  /// `GET /dispatch/slips/:id` — full slip, used by the printable detail
  /// screen so it can render the QR + signatures fresh.
  Future<DplApiResponse<DplDispatchSlip>> getDispatchSlip(int id) {
    return _send<DplDispatchSlip>(
      () => _dio.get(DplPaths.dispatchSlipById(id)),
      fallback: 'Failed to load dispatch slip.',
      fromJson: _oneDispatchSlip,
    );
  }

  /// `POST /dispatch/slips/:id/qa-approve` — QA signs off; status moves
  /// to `pending_pdi`. Server rejects with `INVALID_STATUS` if the slip
  /// isn't currently `pending_qa`.
  Future<DplApiResponse<DplDispatchSlip>> qaApproveDispatchSlip(
    int id, {
    String? remarks,
  }) {
    return _send<DplDispatchSlip>(
      () => _dio.post(
        DplPaths.dispatchSlipQaApprove(id),
        data: {
          if (remarks != null && remarks.trim().isNotEmpty)
            'remarks': remarks.trim(),
        },
      ),
      fallback: 'Failed to QA-approve slip.',
      fromJson: _oneDispatchSlip,
    );
  }

  Future<DplApiResponse<DplDispatchSlip>> qaRejectDispatchSlip(
    int id, {
    required String reason,
  }) {
    return _send<DplDispatchSlip>(
      () => _dio.post(
        DplPaths.dispatchSlipQaReject(id),
        data: {'reason': reason.trim()},
      ),
      fallback: 'Failed to reject slip.',
      fromJson: _oneDispatchSlip,
    );
  }

  /// `POST /dispatch/slips/:id/pdi-approve` — final gate; response carries
  /// the populated `qr_payload`. Backend will return `SAME_USER_FORBIDDEN`
  /// if the same user QA-approved this slip.
  Future<DplApiResponse<DplDispatchSlip>> pdiApproveDispatchSlip(
    int id, {
    String? remarks,
  }) {
    return _send<DplDispatchSlip>(
      () => _dio.post(
        DplPaths.dispatchSlipPdiApprove(id),
        data: {
          if (remarks != null && remarks.trim().isNotEmpty)
            'remarks': remarks.trim(),
        },
      ),
      fallback: 'Failed to PDI-approve slip.',
      fromJson: _oneDispatchSlip,
    );
  }

  Future<DplApiResponse<DplDispatchSlip>> pdiRejectDispatchSlip(
    int id, {
    required String reason,
  }) {
    return _send<DplDispatchSlip>(
      () => _dio.post(
        DplPaths.dispatchSlipPdiReject(id),
        data: {'reason': reason.trim()},
      ),
      fallback: 'Failed to reject slip.',
      fromJson: _oneDispatchSlip,
    );
  }

  /// `POST /dispatch/slips/:id/mark-dispatched` — Dispatch (or Manager)
  /// confirms the goods have physically left. Permanently decreases the
  /// available-for-dispatch qty on the parent (machine, part) bucket.
  Future<DplApiResponse<DplDispatchSlip>> markDispatchSlipDispatched(int id) {
    return _send<DplDispatchSlip>(
      () => _dio.post(DplPaths.dispatchSlipMarkDispatched(id)),
      fallback: 'Failed to mark slip dispatched.',
      fromJson: _oneDispatchSlip,
    );
  }

  /// `GET /dispatch/slips/verify?token=…` — public verifier consumed by
  /// gate staff scanning the printed QR. No Authorization header is
  /// required by the backend, but we send the JWT anyway when present;
  /// the route ignores it.
  Future<DplApiResponse<DplDispatchSlipVerification>> verifyDispatchSlip(
    String token,
  ) {
    return _send<DplDispatchSlipVerification>(
      () => _dio.get(
        DplPaths.dispatchSlipVerify,
        queryParameters: {'token': token},
      ),
      fallback: 'Failed to verify slip.',
      fromJson: (data) {
        if (data is Map) {
          return DplDispatchSlipVerification.fromJson(
            Map<String, dynamic>.from(data),
          );
        }
        return const DplDispatchSlipVerification(verified: false);
      },
    );
  }

  /// Shared fromJson for every single-slip endpoint. Tolerates both the
  /// envelope-stripped shape (`{ id: ... }`) and a `{ slip: { id: ... } }`
  /// wrapper.
  DplDispatchSlip _oneDispatchSlip(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      final inner = map['slip'];
      if (inner is Map) {
        return DplDispatchSlip.fromJson(Map<String, dynamic>.from(inner));
      }
      return DplDispatchSlip.fromJson(map);
    }
    throw const FormatException('Expected object response for dispatch slip.');
  }

  /// `GET /manager/trolley-photos/:id/image` — manager view of the
  /// raw image bytes.
  Future<DplApiResponse<Uint8List>> getManagerTrolleyPhotoBytes(
    int id,
  ) async {
    try {
      final response = await _dio.get<List<int>>(
        DplPaths.managerTrolleyPhotoImage(id),
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        return DplApiResponse.error('Empty trolley photo response.');
      }
      return DplApiResponse.ok(Uint8List.fromList(data));
    } on DioException catch (e) {
      return DplErrorMapper.fromDio<Uint8List>(
        e,
        fallback: 'Failed to load trolley photo.',
      );
    } catch (e) {
      return DplErrorMapper.fromObject<Uint8List>(
        e,
        fallback: 'Failed to load trolley photo.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // List/one helpers
  // ---------------------------------------------------------------------------

  /// Converts the [data] payload of a single-object endpoint into [T].
  ///
  /// Many DPL endpoints wrap the object under a singular key (for example
  /// `{plan: {...}}`, `{item: {...}}`, `{machine: {...}}`). We unwrap the
  /// first matching key transparently so callers don't need to know.
  T Function(dynamic) _oneFrom<T>(T Function(Map<String, dynamic>) fromMap) {
    const wrapperKeys = <String>[
      'plan',
      'item',
      'machine',
      'part',
      'supervisor',
      'reason',
      'downtime_reason',
      'downtimeReason',
      'user',
      'record',
    ];

    return (data) {
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        for (final key in wrapperKeys) {
          final inner = map[key];
          if (inner is Map) {
            return fromMap(Map<String, dynamic>.from(inner));
          }
        }
        return fromMap(map);
      }
      throw const FormatException('Expected object response.');
    };
  }

  List<T> Function(dynamic) _listFrom<T>(
    T Function(Map<String, dynamic>) fromMap,
  ) {
    // Common backend wrapping keys we accept transparently.
    const candidateKeys = <String>[
      'items',
      'results',
      'data',
      'rows',
      'records',
      'machines',
      'supervisors',
      'parts',
      'plans',
      'reasons',
      'downtime_reasons',
      'downtimeReasons',
      'users',
      'shifts',
      'manpower',
      'manpower_logs',
      'manpowerLogs',
      'downtimes',
      'alerts',
      'pauses',
      'verifications',
    ];

    return (data) {
      List<dynamic> list;
      if (data is List) {
        list = data;
      } else if (data is Map) {
        list = const <dynamic>[];
        for (final key in candidateKeys) {
          final v = data[key];
          if (v is List) {
            list = v;
            break;
          }
        }
      } else {
        list = const <dynamic>[];
      }

      return list
          .whereType<Map>()
          .map((e) => fromMap(Map<String, dynamic>.from(e)))
          .toList();
    };
  }
}

// -----------------------------------------------------------------------------
// Auxiliary auth DTOs (only used by the optional DPL-native login flow)
// -----------------------------------------------------------------------------

class DplLoginResult {
  final String token;
  final DplUserProfile? user;

  const DplLoginResult({required this.token, this.user});

  factory DplLoginResult.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    return DplLoginResult(
      token: json['token']?.toString() ?? '',
      user: rawUser is Map
          ? DplUserProfile.fromJson(Map<String, dynamic>.from(rawUser))
          : null,
    );
  }
}

class DplUserProfile {
  final int id;
  final String name;
  final String email;
  final String role;

  /// Backend now bundles the user's active organization on every
  /// `/auth/login` and `/auth/me` response. `organizationId` is the FK
  /// the JWT carries; `organization` is the resolved tenant record we
  /// render in the AppBar / profile drawer. Both may be null if the
  /// user record is misconfigured server-side — code handling that
  /// case should treat it as the `NO_ORGANIZATION` error path.
  final int? organizationId;
  final DplOrganization? organization;

  const DplUserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.organizationId,
    this.organization,
  });

  factory DplUserProfile.fromJson(Map<String, dynamic> json) {
    final rawOrg = json['organization'];
    return DplUserProfile(
      id: json['id'] is int ? json['id'] as int : 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      organizationId:
          json['organization_id'] is int ? json['organization_id'] as int : null,
      organization: rawOrg is Map
          ? DplOrganization.fromJson(Map<String, dynamic>.from(rawOrg))
          : null,
    );
  }
}

// -----------------------------------------------------------------------------
// Riverpod provider
// -----------------------------------------------------------------------------

final dplApiServiceProvider = Provider<DplApiService>((ref) {
  return DplApiService(ref.watch(dplDioProvider));
});
