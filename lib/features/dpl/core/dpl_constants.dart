/// Endpoint paths and status enums for the Daily Production Loading module.
///
/// All paths are relative to [AppConstants.dplApiBaseUrl]
/// (`https://.../api/v1/dpl`).
class DplPaths {
  // Auth
  static const String authLogin = '/auth/login';
  static const String authMe = '/auth/me';
  static const String authLogout = '/auth/logout';
  static const String authChangePassword = '/auth/change-password';

  // Manager — dashboard
  static const String dashboard = '/manager/dashboard';
  static const String alerts = '/manager/alerts';

  // Manager — masters
  static const String machines = '/manager/machines';
  static String machineById(int id) => '/manager/machines/$id';

  static const String parts = '/manager/parts';
  static String partById(int id) => '/manager/parts/$id';

  static const String supervisors = '/manager/supervisors';

  static const String downtimeReasons = '/manager/downtime-reasons';
  static String downtimeReasonById(int id) => '/manager/downtime-reasons/$id';

  // Manager — plans
  static const String plansUploadExcel = '/manager/plans/upload-excel';
  static const String plans = '/manager/plans';
  static String planById(int id) => '/manager/plans/$id';
  static String planLock(int id) => '/manager/plans/$id/lock';
  static String planChangeStatus(int id) =>
      '/manager/plans/$id/change-status';
  static String planItemChangeStatus(int planId, int itemId) =>
      '/manager/plans/$planId/items/$itemId/change-status';
  static String planItemCarryForward(int planId, int itemId) =>
      '/manager/plans/$planId/items/$itemId/carry-forward';
  static const String carryForwardCandidates =
      '/manager/plans/carry-forward-candidates';
  static String planItems(int id) => '/manager/plans/$id/items';
  static String planItemById(int planId, int itemId) =>
      '/manager/plans/$planId/items/$itemId';
  static String managerPlanPauses(int id) => '/manager/plans/$id/pauses';
  static String managerPlanItemPauses(int planId, int itemId) =>
      '/manager/plans/$planId/items/$itemId/pauses';

  // Manager — reports
  static const String reportPlanVsActual = '/manager/reports/plan-vs-actual';
  static const String reportDowntime = '/manager/reports/downtime';
  static const String reportDowntimeEvents =
      '/manager/reports/downtime/events';
  static const String reportSupervisorPerformance =
      '/manager/reports/supervisor-performance';
  static const String reportPartWise = '/manager/reports/part-wise';
  static const String reportExport = '/manager/reports/export';
  static const String reportDplChart = '/manager/reports/dpl-chart';

  // Manager — shifts master
  static const String shifts = '/manager/shifts';
  static String shiftById(int id) => '/manager/shifts/$id';

  // Manager — manpower master
  static const String manpower = '/manager/manpower';
  static String manpowerById(int id) => '/manager/manpower/$id';

  // Supervisor — bulk manpower entry for today
  static const String supervisorManpowerToday =
      '/supervisor/manpower/today';

  // Supervisor
  static const String supervisorToday = '/supervisor/today';
  static String supervisorPlan(int id) => '/supervisor/plans/$id';
  static String supervisorItemStart(int planId, int itemId) =>
      '/supervisor/plans/$planId/items/$itemId/start';
  static String supervisorItemStop(int planId, int itemId) =>
      '/supervisor/plans/$planId/items/$itemId/stop';
  static String supervisorItemActual(int planId, int itemId) =>
      '/supervisor/plans/$planId/items/$itemId/actual';
  static String supervisorItemPause(int planId, int itemId) =>
      '/supervisor/plans/$planId/items/$itemId/pause';
  static String supervisorItemResume(int planId, int itemId) =>
      '/supervisor/plans/$planId/items/$itemId/resume';
  static String supervisorItemPauses(int planId, int itemId) =>
      '/supervisor/plans/$planId/items/$itemId/pauses';
  static String supervisorPlanPauses(int planId) =>
      '/supervisor/plans/$planId/pauses';
  static String supervisorDowntimeStart(int planId) =>
      '/supervisor/plans/$planId/downtime/start';
  static String supervisorDowntimeResume(int downtimeId) =>
      '/supervisor/downtime/$downtimeId/resume';
  static String supervisorPlanDowntimes(int planId) =>
      '/supervisor/plans/$planId/downtimes';
  static const String supervisorShiftSummary = '/supervisor/shift/summary';
  static const String supervisorShiftSubmit = '/supervisor/shift/submit';
  static const String supervisorDowntimeReasons =
      '/supervisor/downtime-reasons';

  // Supervisor — identity verification (selfie gate)
  static const String supervisorIdentityStatus =
      '/supervisor/identity/status';
  static const String supervisorIdentityVerify =
      '/supervisor/identity/verify';
  static String supervisorIdentityPhoto(int id) =>
      '/supervisor/identity/$id/photo';

  // Manager — identity-verification audit log
  static const String managerIdentityVerifications =
      '/manager/identity-verifications';
  static String managerIdentityPhoto(int id) =>
      '/manager/identity-verifications/$id/photo';
  static String managerIdentityFlag(int id) =>
      '/manager/identity-verifications/$id/flag';

  // Supervisor — trolley photo capture (gate before STOP)
  static String supervisorItemTrolleyPhoto(int planId, int itemId) =>
      '/supervisor/plans/$planId/items/$itemId/trolley-photo';
  static String supervisorTrolleyPhotoImage(int id) =>
      '/supervisor/trolley-photos/$id/image';

  // Manager — trolley photo audit log
  static const String managerTrolleyPhotos = '/manager/trolley-photos';
  static String managerTrolleyPhotoImage(int id) =>
      '/manager/trolley-photos/$id/image';

  // Manager — live banner (active downtimes across all plans/machines).
  static const String managerActiveDowntimes = '/manager/active-downtimes';

  // Production summary — aggregate of total actual qty produced per
  // (machine, part) bucket. Same endpoint is consumed by the Manager
  // and by the downstream Dispatch / QA / PDI viewers; backend gates
  // access by JWT role.
  static const String productionSummary =
      '/manager/production-summary';
  static const String productionSummaryOne =
      '/manager/production-summary/one';

  // Manager — force-close a stuck/orphaned active downtime. Manager-
  // scoped recovery route; differs from the supervisor `resume` route
  // in that it doesn't require the original supervisor to be online.
  static String managerDowntimeClose(int downtimeId) =>
      '/manager/downtime/$downtimeId/close';

  // Plants — hardcoded 3-plant mapping (Nexon EV / TML PV / MG Motors)
  // served from a backend config file. Any DPL role can read the list.
  static const String plants = '/plants';

  // Dispatch slip workflow — Dispatch → QA → PDI three-step approval
  // pipeline with an HMAC-signed QR payload printed on the slip. Roles
  // are gated server-side; the verify endpoint is public.
  static const String dispatchSlips = '/dispatch/slips';
  static String dispatchSlipById(int id) => '/dispatch/slips/$id';
  static String dispatchSlipQaApprove(int id) =>
      '/dispatch/slips/$id/qa-approve';
  static String dispatchSlipQaReject(int id) =>
      '/dispatch/slips/$id/qa-reject';
  static String dispatchSlipPdiApprove(int id) =>
      '/dispatch/slips/$id/pdi-approve';
  static String dispatchSlipPdiReject(int id) =>
      '/dispatch/slips/$id/pdi-reject';
  static String dispatchSlipMarkDispatched(int id) =>
      '/dispatch/slips/$id/mark-dispatched';
  static const String dispatchSlipVerify = '/dispatch/slips/verify';
}

/// Allowed `context` values for the identity-verify endpoint.
class DplIdentityContext {
  static const String login = 'login';
  static const String planAccess = 'plan_access';
  static const String itemStart = 'item_start';
  static const String downtimeStart = 'downtime_start';
}

/// Backend status values for production plans.
class DplPlanStatus {
  static const String draft = 'draft';
  static const String published = 'published';
  static const String inProgress = 'in_progress';
  static const String completed = 'completed';
  static const String locked = 'locked';

  static const List<String> all = <String>[
    draft,
    published,
    inProgress,
    completed,
    locked,
  ];

  static String label(String status) {
    switch (status) {
      case draft:
        return 'Draft';
      case published:
        return 'Published';
      case inProgress:
        return 'In Progress';
      case completed:
        return 'Completed';
      case locked:
        return 'Locked';
      default:
        return status.isEmpty
            ? '-'
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  /// Per backend update (2026-05-21): manager can edit a plan in ANY
  /// status except locked. Backend returns INVALID_STATUS for locked.
  static bool isEditable(String status) => status != locked;

  static bool isLockable(String status) =>
      status == published || status == inProgress;

  static bool isDeletable(String status) => status == draft;

  /// Read-only is now equivalent to locked. Use the change-status
  /// endpoint to move out of locked before editing.
  static bool isReadOnly(String status) => status == locked;
}

/// Downtime-reason categories.
class DplDowntimeCategory {
  static const String planned = 'planned';
  static const String unplanned = 'unplanned';

  static const List<String> all = <String>[planned, unplanned];

  static String label(String category) {
    switch (category) {
      case planned:
        return 'Planned';
      case unplanned:
        return 'Unplanned';
      default:
        return category;
    }
  }
}

/// Report export formats supported by the backend.
class DplReportFormat {
  static const String xlsx = 'xlsx';
  static const String pdf = 'pdf';
  static const String csv = 'csv';
}

/// Lifecycle status values for `dpl.dpl_dispatch_slips`.
///
/// Status machine:
///   pending_qa → pending_pdi → approved → dispatched
///              ↘ rejected ↙
class DplDispatchSlipStatus {
  static const String pendingQa = 'pending_qa';
  static const String pendingPdi = 'pending_pdi';
  static const String approved = 'approved';
  static const String dispatched = 'dispatched';
  static const String rejected = 'rejected';

  static const List<String> all = <String>[
    pendingQa,
    pendingPdi,
    approved,
    dispatched,
    rejected,
  ];

  /// Short, user-facing label.
  static String label(String status) {
    switch (status) {
      case pendingQa:
        return 'Pending QA';
      case pendingPdi:
        return 'Pending PDI';
      case approved:
        return 'Approved';
      case dispatched:
        return 'Dispatched';
      case rejected:
        return 'Rejected';
      default:
        if (status.isEmpty) return '-';
        return status[0].toUpperCase() + status.substring(1);
    }
  }

  /// True while the slip is still moving through the approval pipeline.
  static bool isOpen(String status) =>
      status == pendingQa || status == pendingPdi;

  /// True once both quality gates have signed off (QR is populated).
  static bool isApproved(String status) => status == approved;

  /// True once stock has physically left the plant.
  static bool isClosed(String status) =>
      status == dispatched || status == rejected;
}

/// Default copy used in the upload-plan form.
class DplDefaults {
  static const String planReleasedBy = 'Vistar Logitek Pvt. Ltd.';
  static const String planApprovedBy = 'Grupo Antolin India Pvt. Ltd';
}
