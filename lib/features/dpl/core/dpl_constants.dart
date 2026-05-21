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
  static String planItems(int id) => '/manager/plans/$id/items';
  static String planItemById(int planId, int itemId) =>
      '/manager/plans/$planId/items/$itemId';
  static String managerPlanPauses(int id) => '/manager/plans/$id/pauses';
  static String managerPlanItemPauses(int planId, int itemId) =>
      '/manager/plans/$planId/items/$itemId/pauses';

  // Manager — reports
  static const String reportPlanVsActual = '/manager/reports/plan-vs-actual';
  static const String reportDowntime = '/manager/reports/downtime';
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

/// Default copy used in the upload-plan form.
class DplDefaults {
  static const String planReleasedBy = 'Vistar Logitek Pvt. Ltd.';
  static const String planApprovedBy = 'Grupo Antolin India Pvt. Ltd';
}
